// claimPortalAppointments  POST  Authorization: Bearer <ID token da conta do APP>
//                          body { phoneIdToken }  (ID token do login por celular do portal, recente)
// -> { moved, attachments }. Traz as consultas CONCLUÍDAS do portal para a conta do app.
const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const lib = require("./claim_portal_lib");
const core = require("./claim_portal_core");

exports.claimPortalAppointments = onRequest({ region: "southamerica-east1", cors: true }, async (req, res) => {
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });
  const h = req.headers.authorization || "";
  const appToken = h.startsWith("Bearer ") ? h.slice(7) : null;
  const phoneToken = String((req.body || {}).phoneIdToken || "");
  if (!appToken || !phoneToken) return res.status(401).json({ error: "Tokens não fornecidos" });
  let appTok; let phoneTok;
  try {
    appTok = await admin.auth().verifyIdToken(appToken);
    phoneTok = await admin.auth().verifyIdToken(phoneToken);
  } catch (_) {
    return res.status(401).json({ error: "Token inválido ou expirado" });
  }
  const v = lib.validateTokens(appTok, phoneTok, Date.now());
  if (!v.ok) return res.status(400).json({ error: v.error });
  try {
    const r = await core.claim({ appUid: v.appUid, phoneUid: v.phoneUid });
    console.log(`claimPortalAppointments: ${r.moved} pedidos de ${v.phoneUid} -> ${v.appUid}`);
    return res.json({ ok: true, moved: r.moved, attachments: r.attachments });
  } catch (e) {
    console.error("claimPortalAppointments:", e.message);
    return res.status(500).json({ error: "Não foi possível trazer as consultas agora. Tente novamente." });
  }
});
