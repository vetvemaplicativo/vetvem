// Realocação para pedidos do PORTAL (sem app/push): a tutora escolhe outro profissional por
// uma página do portal, aberta por um link com chave secreta enviado por e-mail.
//   portalRelocationInfo   {appointmentId, token}              -> situação e opções
//   portalChooseRelocation {appointmentId, token, vetId}       -> escolhe um profissional
//   portalCancelRelocation {appointmentId, token}              -> cancela e estorna tudo
// A chave fica em relocation_tokens/{id} (coleção que nenhum cliente lê).
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const { chooseVet, cancelRelocationNow, verifyPortalToken } = require("./realocacao_core");
const { isPortal } = require("./realocacao_lib");

const RESEND_SECRET = defineSecret("RESEND_API_KEY");
const resendKeyOrNull = () => { try { return RESEND_SECRET.value() || null; } catch (_) { return null; } };

// Valida método, chave e pedido; devolve { ref, appt } ou responde com erro e devolve null.
async function open(req, res) {
  if (req.method !== "POST") { res.status(405).json({ error: "Method not allowed" }); return null; }
  const { appointmentId, token } = req.body || {};
  if (!appointmentId || !token) { res.status(400).json({ error: "Link inválido." }); return null; }
  if (!(await verifyPortalToken(String(appointmentId), String(token)))) {
    res.status(403).json({ error: "Link inválido ou expirado." });
    return null;
  }
  const ref = admin.firestore().collection("appointments").doc(String(appointmentId));
  const appt = (await ref.get()).data();
  if (!appt || !isPortal(appt)) { res.status(404).json({ error: "Pedido não encontrado." }); return null; }
  return { ref, appt };
}

const OPTS = { region: "southamerica-east1", cors: true };

exports.portalRelocationInfo = onRequest(OPTS, async (req, res) => {
  const o = await open(req, res);
  if (!o) return;
  const a = o.appt;
  const awaiting = a.status === "pending_confirmation" && a.relocationStatus === "awaiting_tutor" &&
    Date.now() <= Number(a.relocationDeadline || 0);
  return res.json({
    ok: true,
    state: awaiting ? "choose" : a.relocationStatus === "awaiting_vet" ? "waiting_vet"
      : a.status === "confirmed" ? "confirmed" : "closed",
    date: a.date, time: a.time, tutorName: a.tutorName || "",
    originalVetName: a.originalVetName || a.relocationLastVetName || "",
    paid: a.originalValue || a.value || "",
    deadline: awaiting ? a.relocationDeadline : null,
    vetName: a.relocationStatus === "awaiting_vet" || a.status === "confirmed" ? a.vetName : "",
    options: awaiting ? (a.relocationOptions || []) : [],
  });
});

exports.portalChooseRelocation = onRequest({ ...OPTS, secrets: [RESEND_SECRET] }, async (req, res) => {
  const o = await open(req, res);
  if (!o) return;
  const { vetId } = req.body || {};
  if (!vetId) return res.status(400).json({ error: "Profissional não informado." });
  try {
    const r = await chooseVet(o.ref, o.appt, String(vetId), { resendKey: resendKeyOrNull() });
    if (!r.ok) return res.status(r.code).json({ error: r.error });
    return res.json({ ok: true, vetName: r.vetName, price: r.price, deadline: r.deadline });
  } catch (e) {
    console.error("portalChooseRelocation:", e.message);
    return res.status(500).json({ error: "Não foi possível escolher agora. Tente novamente." });
  }
});

exports.portalCancelRelocation = onRequest(OPTS, async (req, res) => {
  const o = await open(req, res);
  if (!o) return;
  if (o.appt.status !== "pending_confirmation" || o.appt.relocationStatus !== "awaiting_tutor") {
    return res.status(409).json({ error: "Não há escolha pendente neste pedido." });
  }
  // O estorno total é feito pelo appointmentHistorian ao ver status = rejected.
  await cancelRelocationNow(o.ref, o.appt);
  return res.json({ ok: true });
});
