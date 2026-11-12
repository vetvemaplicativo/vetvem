// Realocação de profissional — endpoints e agendamento (as regras estão em
// realocacao_lib.js e as operações no Firestore em realocacao_core.js).
//   chooseRelocation {appointmentId, vetId}  (tutor) escolhe um dos profissionais oferecidos
//   cancelRelocation {appointmentId}         (tutor) nenhum serve: encerra e estorna tudo
//   expireRelocations                        (a cada 5 min) tutor não escolheu no prazo: estorna
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { defineSecret } = require("firebase-functions/params");
const { chooseVet, notify, cancelRelocationNow, lastVetFields, sendMail } = require("./realocacao_core");
const { isPortal } = require("./realocacao_lib");
const { ORS_SECRET, AWESOME_SECRET } = require("./travel_core");

const RESEND_SECRET = defineSecret("RESEND_API_KEY");
const resendKeyOrNull = () => { try { return RESEND_SECRET.value() || null; } catch (_) { return null; } };
const { petLabel } = require("./appointment_amount");
const { parseDateTimeMs } = require("./horarios_lib");

async function authUid(req, res) {
  const h = req.headers.authorization || "";
  const token = h.startsWith("Bearer ") ? h.slice(7) : null;
  if (!token) { res.status(401).json({ error: "Token não fornecido" }); return null; }
  try {
    return (await admin.auth().verifyIdToken(token)).uid;
  } catch (_) {
    res.status(401).json({ error: "Token inválido" });
    return null;
  }
}

exports.chooseRelocation = onRequest({ region: "southamerica-east1", cors: false, secrets: [RESEND_SECRET, ORS_SECRET, AWESOME_SECRET] }, async (req, res) => {
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });
  const uid = await authUid(req, res);
  if (!uid) return;
  const { appointmentId, vetId } = req.body || {};
  if (!appointmentId || !vetId) return res.status(400).json({ error: "Dados incompletos." });
  const ref = admin.firestore().collection("appointments").doc(String(appointmentId));
  const appt = (await ref.get()).data();
  if (!appt) return res.status(404).json({ error: "Pedido não encontrado." });
  if (appt.tutorId !== uid) return res.status(403).json({ error: "Este pedido não é seu." });
  try {
    const r = await chooseVet(ref, appt, String(vetId), { resendKey: resendKeyOrNull() });
    if (!r.ok) return res.status(r.code).json({ error: r.error });
    return res.json({ ok: true, vetName: r.vetName, price: r.price, deadline: r.deadline });
  } catch (e) {
    console.error("chooseRelocation:", e.message);
    return res.status(500).json({ error: "Não foi possível escolher agora. Tente novamente." });
  }
});

exports.cancelRelocation = onRequest({ region: "southamerica-east1", cors: false }, async (req, res) => {
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });
  const uid = await authUid(req, res);
  if (!uid) return;
  const { appointmentId } = req.body || {};
  if (!appointmentId) return res.status(400).json({ error: "Pedido não informado." });
  const ref = admin.firestore().collection("appointments").doc(String(appointmentId));
  const appt = (await ref.get()).data();
  if (!appt) return res.status(404).json({ error: "Pedido não encontrado." });
  if (appt.tutorId !== uid) return res.status(403).json({ error: "Este pedido não é seu." });
  if (appt.status !== "pending_confirmation" || appt.relocationStatus !== "awaiting_tutor") {
    return res.status(409).json({ error: "Não há escolha pendente neste pedido." });
  }
  // O estorno total é feito pelo appointmentHistorian ao ver status = rejected.
  await cancelRelocationNow(ref, appt);
  return res.json({ ok: true });
});

exports.expireRelocations = onSchedule(
  { cpu: "gcf_gen1", schedule: "*/5 * * * *", timeZone: "America/Sao_Paulo", region: "southamerica-east1", secrets: [RESEND_SECRET] },
  async () => {
    const db = admin.firestore();
    const now = Date.now();
    const snap = await db.collection("appointments")
      .where("status", "==", "pending_confirmation")
      .where("relocationStatus", "==", "awaiting_tutor").get();
    let n = 0;
    for (const doc of snap.docs) {
      const d = doc.data();
      const apptMs = parseDateTimeMs(d.date, d.time);
      const late = Number(d.relocationDeadline || 0) <= now || (apptMs !== null && apptMs <= now);
      if (!late) continue;
      await doc.ref.update({
        status: "rejected",
        rejectReason: "relocation_expired",
        rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
        relocationStatus: "expired",
        relocationOptions: admin.firestore.FieldValue.delete(),
        relocationDeadline: admin.firestore.FieldValue.delete(),
        ...lastVetFields(d),
      });
      n++;
      if (isPortal(d)) {
        const key = resendKeyOrNull();
        if (key && d.email) {
          try {
            await sendMail(key, d.email, "O prazo para escolher terminou",
              `<p>O prazo para escolher outro profissional para ${petLabel(d, "seu pet")} terminou. O pedido foi encerrado e o valor pago via PIX será estornado.</p>
               <p>Você pode <a href="https://agendar.vetvem.com.br">voltar ao site</a> e agendar de novo quando quiser.</p>`);
          } catch (e) { console.error("expireRelocations email:", e.message); }
        }
      } else {
        await notify(d.tutorId, "⏰ Prazo para escolher terminou",
          `Você não escolheu um profissional para ${petLabel(d, "seu pet")} no prazo. O pedido foi encerrado e o valor será estornado.`,
          { tipo: "realocacao_expirada", appointmentId: doc.id });
      }
    }
    console.log(`expireRelocations: ${n} realocação(ões) expirada(s).`);
  }
);
