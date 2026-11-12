// Adicionais durante o atendimento — endpoints (regras em adicionais_lib.js, operações em
// adicionais_core.js).
//   extraCharge {appointmentId, extraId}  (profissional) fecha o rascunho e devolve o PIX do total
//   extraCancel {appointmentId, extraId}  (profissional) cancela rascunho / cobrança pendente
//   dailyExtraPayouts                     (08:10) repasses dos adicionais pagos há 2+ dias
// O rascunho (appointments/{id}/extras/{extraId}, status "draft") é gravado pelo app do profissional
// sob as regras do Firestore; o total é sempre recalculado no servidor.
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { MP_SECRET, MP_SECRET_V2 } = require("./mp_accounts");
const core = require("./adicionais_core");

const ADMIN_EMAIL = "ronalddesouzabr@gmail.com"; // mesma conta que recebe o resumo dos repasses

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

function handler(run) {
  return async (req, res) => {
    if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });
    const uid = await authUid(req, res);
    if (!uid) return;
    const { appointmentId, extraId } = req.body || {};
    if (!appointmentId || !extraId) return res.status(400).json({ error: "Dados incompletos." });
    try {
      const r = await run({ appointmentId: String(appointmentId), extraId: String(extraId), uid });
      if (!r.ok) return res.status(r.code).json({ error: r.error });
      return res.json({ ok: true, ...(r.result ? { result: r.result } : {}) });
    } catch (e) {
      console.error("adicionais:", e.message);
      return res.status(500).json({ error: "Não foi possível concluir agora. Tente novamente." });
    }
  };
}

const OPTS = { region: "southamerica-east1", cors: false, secrets: [MP_SECRET, MP_SECRET_V2] };

exports.extraCharge = onRequest(OPTS, handler((a) => core.createCharge(a)));
exports.extraCancel = onRequest(OPTS, handler((a) => core.cancelExtra(a)));

exports.dailyExtraPayouts = onSchedule(
  { cpu: "gcf_gen1", schedule: "10 8 * * *", timeZone: "America/Sao_Paulo", region: "southamerica-east1" },
  async () => {
    const r = await core.processExtraPayouts();
    if (!r.count && !r.held) { console.log("dailyExtraPayouts: nada devido hoje."); return; }
    if (r.held) console.log(`dailyExtraPayouts: ${r.held} retido(s) por troca recente de chave PIX.`);
    if (!r.count) return;
    try {
      const adminUser = await admin.auth().getUserByEmail(ADMIN_EMAIL);
      await admin.firestore().collection("notifications").doc(adminUser.uid).collection("pending").add({
        title: `💸 ${r.count} repasse(s) de adicionais — total R$ ${r.total.toFixed(2).replace(".", ",")}`,
        body: r.lines.join("\n"),
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      console.error("dailyExtraPayouts: falha ao notificar admin:", e.message);
    }
    console.log(`dailyExtraPayouts: ${r.count} repasses, total R$ ${r.total.toFixed(2)}`);
  }
);
