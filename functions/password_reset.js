// E-mail de redefinição de senha com a marca VetVem (logo + "Equipe VetVem").
// Substitui o e-mail padrão do Firebase, que não aceita imagem e sai de
// noreply@...firebaseapp.com. O link é gerado pelo Admin SDK (mesmo fluxo
// seguro do Firebase) e o e-mail sai pelo Resend, domínio mail.vetvem.com.br.
//
// Segurança: responde SEMPRE igual (existindo ou não a conta) para não revelar
// quem tem cadastro; só envia para contas com senha (e-mail/senha), e no máximo
// 1 envio por minuto por e-mail.
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const axios = require("axios");
const crypto = require("crypto");

const RESEND_SECRET = defineSecret("RESEND_API_KEY");
const LOGO_URL = "https://vetvem.com.br/wp-content/uploads/vetvem-email/logo-vetvem-email.png";
const ICON_URL = "https://vetvem.com.br/wp-content/uploads/vetvem-email/icone-vetvem-email.png";
const FROM = "VetVem <suporte@mail.vetvem.com.br>";
const REPLY_TO = "suporte@vetvem.com.br";
const COOLDOWN_MS = 60 * 1000;

function buildHtml(link) {
  return `<!doctype html>
<html lang="pt-BR"><body style="margin:0;padding:0;background:#f4f4f5;font-family:Arial,Helvetica,sans-serif;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f4f5;padding:24px 12px;">
    <tr><td align="center">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#ffffff;border-radius:12px;overflow:hidden;">
        <tr><td align="center" style="padding:28px 24px 8px;">
          <img src="${ICON_URL}" alt="VetVem" width="88" height="88" style="display:block;border:0;width:88px;height:88px;">
        </td></tr>
        <tr><td style="padding:16px 28px 8px;color:#1f2937;font-size:15px;line-height:1.6;">
          <h2 style="margin:8px 0 12px;font-size:20px;color:#111827;">Redefinir sua senha</h2>
          <p style="margin:0 0 14px;">Olá! Recebemos um pedido para criar uma nova senha de acesso ao VetVem.</p>
          <p style="margin:0 0 22px;">Toque no botão abaixo para escolher a nova senha:</p>
          <p style="margin:0 0 24px;text-align:center;">
            <a href="${link}" style="display:inline-block;background:#FF6B2B;color:#ffffff;text-decoration:none;font-weight:bold;padding:14px 28px;border-radius:10px;">Criar nova senha</a>
          </p>
          <p style="margin:0 0 6px;font-size:13px;color:#6b7280;">Se o botão não funcionar, copie e cole este endereço no navegador:</p>
          <p style="margin:0 0 18px;font-size:10px;line-height:1.4;color:#9ca3af;word-break:break-all;"><a href="${link}" style="color:#9ca3af;text-decoration:none;">${link}</a></p>
          <p style="margin:0 0 4px;font-size:13px;color:#6b7280;">Se você não pediu isso, ignore este e-mail: sua senha continua a mesma.</p>
        </td></tr>
        <tr><td style="padding:12px 28px 28px;color:#1f2937;font-size:14px;line-height:1.5;">
          <p style="margin:0 0 10px;">Abraços,<br><strong>Equipe VetVem</strong></p>
          <img src="${LOGO_URL}" alt="VetVem" width="110" style="display:block;border:0;width:110px;max-width:110px;height:auto;border-radius:6px;margin:0 0 12px;">
          <p style="margin:0;font-size:12px;line-height:1.5;color:#9ca3af;">Dúvidas? Responda este e-mail ou escreva para <a href="mailto:suporte@vetvem.com.br" style="color:#9ca3af;">suporte@vetvem.com.br</a>.</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body></html>`;
}

exports.sendBrandedPasswordReset = onRequest(
  { region: "southamerica-east1", secrets: [RESEND_SECRET], cors: false },
  async (req, res) => {
    if (req.method !== "POST") return res.status(405).json({ ok: false });
    const email = String((req.body && req.body.email) || "").trim().toLowerCase();
    // Resposta única, independentemente do que acontecer abaixo.
    const done = () => res.json({ ok: true });
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 200) return done();

    try {
      const db = admin.firestore();
      const key = crypto.createHash("sha256").update(email).digest("hex");
      const ref = db.collection("passwordResetThrottle").doc(key);
      const snap = await ref.get();
      const last = snap.exists ? snap.data().at?.toMillis?.() || 0 : 0;
      if (Date.now() - last < COOLDOWN_MS) return done();
      await ref.set({ at: admin.firestore.FieldValue.serverTimestamp() });

      let user;
      try {
        user = await admin.auth().getUserByEmail(email);
      } catch (_) {
        return done(); // conta inexistente: não revela
      }
      if (!user.providerData.some((p) => p.providerId === "password")) return done();

      const link = await admin.auth().generatePasswordResetLink(email);
      await axios.post(
        "https://api.resend.com/emails",
        {
          from: FROM,
          reply_to: REPLY_TO,
          to: [email],
          subject: "Redefinir sua senha do VetVem",
          html: buildHtml(link),
        },
        { headers: { Authorization: `Bearer ${RESEND_SECRET.value()}` } }
      );
    } catch (e) {
      console.error("sendBrandedPasswordReset:", e.response?.data || e.message);
    }
    return done();
  }
);

