// E-mail do prontuário para quem agendou pelo portal (regras em prontuario_email_lib.js, operações
// em prontuario_email_core.js).
//   sendProntuarioEmail          (gatilho) pedido do portal com sentToClient=true: manda o prontuário
//                                por e-mail uma vez e, depois, só os complementos novos
//   adminResendProntuarioEmail   {appointmentId, to?}  (painel) reenvia o prontuário completo
const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const { defineSecret } = require("firebase-functions/params");
const core = require("./prontuario_email_core");

const RESEND_SECRET = defineSecret("RESEND_API_KEY");

exports.sendProntuarioEmail = onDocumentUpdated(
  { document: "appointments/{appointmentId}", region: "southamerica-east1", secrets: [RESEND_SECRET] },
  async (event) => {
    const after = event.data && event.data.after && event.data.after.data();
    // Filtro barato antes de abrir transação: o gatilho dispara em TODA atualização de pedido.
    if (!after || after.bookingOrigin !== "portal_web" || after.sentToClient !== true) return;
    await core.handleUpdate({ ref: event.data.after.ref, resendKey: RESEND_SECRET.value() });
  }
);

async function adminOnly(req, res) {
  const h = req.headers.authorization || "";
  const token = h.startsWith("Bearer ") ? h.slice(7) : null;
  if (!token) { res.status(401).json({ error: "Token não fornecido" }); return false; }
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    if (decoded.admin !== true) { res.status(403).json({ error: "Acesso restrito a administradores" }); return false; }
    return true;
  } catch (_) {
    res.status(401).json({ error: "Token inválido" });
    return false;
  }
}

exports.adminResendProntuarioEmail = onRequest(
  { region: "southamerica-east1", cors: true, cpu: "gcf_gen1", secrets: [RESEND_SECRET] },
  async (req, res) => {
    if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });
    if (!(await adminOnly(req, res))) return;
    const id = String((req.body || {}).appointmentId || "");
    if (!id) return res.status(400).json({ error: "appointmentId é obrigatório" });
    const ref = admin.firestore().collection("appointments").doc(id);
    const appt = (await ref.get()).data();
    if (!appt) return res.status(404).json({ error: "Agendamento não encontrado" });
    if (!appt.prontuario) return res.status(400).json({ error: "Este pedido ainda não tem prontuário." });
    const to = String((req.body || {}).to || appt.email || "").trim();
    if (!to.includes("@")) return res.status(400).json({ error: "Informe um e-mail válido." });
    try {
      const r = await core.resendFull({ appt, to, resendKey: RESEND_SECRET.value() });
      await ref.update({ prontuarioEmailResentAt: Date.now() });
      return res.json({ result: { ok: true, to, ...r } });
    } catch (e) {
      console.error("adminResendProntuarioEmail:", e.response?.data || e.message);
      return res.status(500).json({ error: "Erro ao enviar e-mail" });
    }
  }
);
