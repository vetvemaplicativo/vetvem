// Contatos de um agendamento para o painel admin: telefone/e-mail do tutor e do
// profissional. O telefone de quem agenda pelo portal só existe no Auth (login por
// telefone), por isso vem do servidor e só para administradores (claim admin).
const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { pickContact } = require("./admin_contacts_lib");
const { portalLink } = require("./realocacao_core");

async function contactOf(uid, appt, fallbackName) {
  if (!uid) return { name: fallbackName || "", phone: "", email: "" };
  const db = admin.firestore();
  const user = (await db.collection("users").doc(uid).get()).data() || {};
  let authUser = null;
  try { authUser = await admin.auth().getUser(uid); } catch (_) { /* conta removida */ }
  const c = pickContact(user, authUser, appt);
  return { name: String(user.name || fallbackName || ""), ...c };
}

exports.adminAppointmentContacts = onRequest({ region: "southamerica-east1", cors: true, cpu: "gcf_gen1" }, async (req, res) => {
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });
  const h = req.headers.authorization || "";
  const token = h.startsWith("Bearer ") ? h.slice(7) : null;
  if (!token) return res.status(401).json({ error: "Token não fornecido" });
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    if (decoded.admin !== true) return res.status(403).json({ error: "Acesso restrito a administradores" });
  } catch (_) {
    return res.status(401).json({ error: "Token inválido" });
  }
  const { appointmentId } = req.body || {};
  if (!appointmentId) return res.status(400).json({ error: "appointmentId é obrigatório" });
  const appt = (await admin.firestore().collection("appointments").doc(String(appointmentId)).get()).data();
  if (!appt) return res.status(404).json({ error: "Agendamento não encontrado" });
  const [tutor, vet] = await Promise.all([
    contactOf(appt.tutorId, appt, appt.tutorName),
    contactOf(appt.vetId, null, appt.vetName),
  ]);
  // Pedido do portal esperando a tutora escolher outro profissional: link para mandar no WhatsApp.
  let relocationLink = "";
  if (appt.bookingOrigin === "portal_web" && appt.relocationStatus === "awaiting_tutor") {
    relocationLink = await portalLink(String(appointmentId));
  }
  return res.json({ result: { tutor, vet, relocationLink } });
});
