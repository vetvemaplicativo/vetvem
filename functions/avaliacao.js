// Avaliação do atendimento por LINK (WhatsApp), sem login:
//   adminCreateReviewLink {appointmentId}                       -> (painel) cria/recupera o link
//   reviewInfo            {appointmentId, token}                -> dados para a página /avaliar
//   reviewSubmit          {appointmentId, token, rating, comment} -> grava a nota no pedido
// A chave fica em review_tokens/{id} (coleção que nenhum cliente lê). A nota vai para os mesmos
// campos do app (rating/comment) e o agregado do profissional é recalculado como no app.
const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const crypto = require("crypto");
const axios = require("axios");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");

const RESEND_SECRET = defineSecret("RESEND_API_KEY");

const PORTAL_URL = "https://agendar.vetvem.com.br";
const OPTS = { region: "southamerica-east1", cors: true };

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

async function verifyReviewToken(id, token) {
  if (!id || typeof token !== "string" || !token) return false;
  const t = (await admin.firestore().collection("review_tokens").doc(String(id)).get()).data();
  if (!t || typeof t.token !== "string" || t.token.length !== token.length) return false;
  return crypto.timingSafeEqual(Buffer.from(t.token), Buffer.from(token));
}

// Mesma conta do app (profile_controller._updateVetRatingAggregate).
async function updateVetAggregate(appt) {
  const db = admin.firestore();
  const vetId = appt.vetId || "";
  if (!vetId) return;
  const snap = await db.collection("appointments").where("vetId", "==", vetId).get();
  let sum = 0; let n = 0; let completed = 0;
  snap.docs.forEach((d) => {
    const x = d.data();
    if (x.status === "completed") completed++;
    if (typeof x.rating === "number" && x.rating > 0) { sum += x.rating; n++; }
  });
  await db.collection("users").doc(vetId).update({
    rating: n ? Math.round((sum / n) * 10) / 10 : 0,
    reviewCount: n,
    completedCount: completed,
  });
}

exports.adminCreateReviewLink = onRequest({ ...OPTS, cpu: "gcf_gen1" }, async (req, res) => {
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });
  if (!(await adminOnly(req, res))) return;
  const id = String((req.body || {}).appointmentId || "");
  if (!id) return res.status(400).json({ error: "appointmentId é obrigatório" });
  const appt = (await admin.firestore().collection("appointments").doc(id).get()).data();
  if (!appt) return res.status(404).json({ error: "Agendamento não encontrado" });
  if (appt.status !== "completed") return res.status(400).json({ error: "Só dá para pedir avaliação de consulta concluída." });
  if (typeof appt.rating === "number" && appt.rating > 0) {
    return res.status(409).json({ error: "Este atendimento já foi avaliado." });
  }
  const tref = admin.firestore().collection("review_tokens").doc(id);
  let token = ((await tref.get()).data() || {}).token;
  if (!token) {
    token = crypto.randomBytes(24).toString("hex");
    await tref.set({ token, at: Date.now() });
  }
  await admin.firestore().collection("appointments").doc(id).update({ reviewLinkAskedAt: Date.now() });
  return res.json({ result: { link: `${PORTAL_URL}/avaliar?id=${id}&t=${token}` } });
});

async function open(req, res) {
  if (req.method !== "POST") { res.status(405).json({ error: "Method not allowed" }); return null; }
  const { appointmentId, token } = req.body || {};
  if (!appointmentId || !token) { res.status(400).json({ error: "Link inválido." }); return null; }
  if (!(await verifyReviewToken(String(appointmentId), String(token)))) {
    res.status(403).json({ error: "Link inválido ou expirado." });
    return null;
  }
  const ref = admin.firestore().collection("appointments").doc(String(appointmentId));
  const appt = (await ref.get()).data();
  if (!appt) { res.status(404).json({ error: "Pedido não encontrado." }); return null; }
  return { ref, appt };
}

exports.reviewInfo = onRequest(OPTS, async (req, res) => {
  const o = await open(req, res);
  if (!o) return;
  const a = o.appt;
  const done = typeof a.rating === "number" && a.rating > 0;
  return res.json({
    ok: true,
    state: done ? "done" : a.status === "completed" ? "open" : "closed",
    tutorName: String(a.tutorName || "").trim().split(" ")[0] || "",
    vetName: a.vetName || "",
    petName: a.petName || "",
    date: a.date || "",
  });
});

exports.reviewSubmit = onRequest(OPTS, async (req, res) => {
  const o = await open(req, res);
  if (!o) return;
  const rating = Number((req.body || {}).rating);
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
    return res.status(400).json({ error: "Escolha de 1 a 5 estrelas." });
  }
  const comment = String((req.body || {}).comment || "").trim().slice(0, 1000);
  if (o.appt.status !== "completed") return res.status(409).json({ error: "Este atendimento ainda não foi concluído." });
  try {
    // Transação: garante uma única avaliação por pedido, mesmo com cliques repetidos.
    const saved = await admin.firestore().runTransaction(async (tx) => {
      const cur = (await tx.get(o.ref)).data() || {};
      if (typeof cur.rating === "number" && cur.rating > 0) return false;
      tx.update(o.ref, {
        rating,
        comment: comment || null,
        ratedAt: admin.firestore.FieldValue.serverTimestamp(),
        ratedVia: "link",
      });
      return true;
    });
    if (!saved) return res.status(409).json({ error: "Este atendimento já foi avaliado. Obrigado!" });
    await updateVetAggregate(o.appt).catch((e) => console.error("reviewSubmit aggregate:", e.message));
    return res.json({ ok: true });
  } catch (e) {
    console.error("reviewSubmit:", e.message);
    return res.status(500).json({ error: "Não foi possível enviar agora. Tente novamente." });
  }
});

// ─── E-mail de avaliação (manual pelo painel e automático) ───────────────────

const esc = (t) => String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

async function ensureLink(id) {
  const tref = admin.firestore().collection("review_tokens").doc(id);
  let token = ((await tref.get()).data() || {}).token;
  if (!token) {
    token = crypto.randomBytes(24).toString("hex");
    await tref.set({ token, at: Date.now() });
  }
  return `${PORTAL_URL}/avaliar?id=${id}&t=${token}`;
}

// E-mail do tutor: do pedido (portal), do cadastro ou do login.
async function tutorEmail(appt) {
  if (appt.email && String(appt.email).includes("@")) return String(appt.email).trim();
  if (!appt.tutorId) return "";
  const u = (await admin.firestore().collection("users").doc(appt.tutorId).get()).data() || {};
  if (u.email && String(u.email).includes("@")) return String(u.email).trim();
  try { return String((await admin.auth().getUser(appt.tutorId)).email || "").trim(); } catch (_) { return ""; }
}

async function sendReviewEmail(resendKey, to, appt, link) {
  const first = String(appt.tutorName || "").trim().split(" ")[0];
  const html = `<div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;color:#1a1a2e">
<p>Olá${first ? ", " + esc(first) : ""}!</p>
<p>Como foi o atendimento de <strong>${esc(appt.petName || "seu pet")}</strong> com <strong>${esc(appt.vetName || "o profissional")}</strong>? Sua opinião leva 20 segundos e ajuda muito.</p>
<p><a href="${link}"><img src="${PORTAL_URL}/og-avaliar.jpg" alt="Avalie o atendimento" width="600" style="width:100%;max-width:600px;height:auto;border-radius:12px"></a></p>
<p style="text-align:center"><a href="${link}" style="display:inline-block;background:#ff6b2b;color:#fff;text-decoration:none;font-weight:bold;padding:14px 28px;border-radius:12px">Avaliar atendimento</a></p>
<p style="font-size:12px;color:#646471">Se o botão não abrir, copie este link: ${link}</p></div>`;
  await axios.post(
    "https://api.resend.com/emails",
    { from: "VetVem <agendamentos@mail.vetvem.com.br>", to: [to], subject: "Como foi o atendimento? Avalie em 20 segundos 🐾", html },
    { headers: { Authorization: `Bearer ${resendKey}` } }
  );
}

exports.adminSendReviewEmail = onRequest({ ...OPTS, cpu: "gcf_gen1", secrets: [RESEND_SECRET] }, async (req, res) => {
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });
  if (!(await adminOnly(req, res))) return;
  const id = String((req.body || {}).appointmentId || "");
  if (!id) return res.status(400).json({ error: "appointmentId é obrigatório" });
  const ref = admin.firestore().collection("appointments").doc(id);
  const appt = (await ref.get()).data();
  if (!appt) return res.status(404).json({ error: "Agendamento não encontrado" });
  if (appt.status !== "completed") return res.status(400).json({ error: "Só dá para pedir avaliação de consulta concluída." });
  if (typeof appt.rating === "number" && appt.rating > 0) return res.status(409).json({ error: "Este atendimento já foi avaliado." });
  const to = await tutorEmail(appt);
  if (!to) return res.status(400).json({ error: "Tutor sem e-mail cadastrado." });
  try {
    await sendReviewEmail(RESEND_SECRET.value(), to, appt, await ensureLink(id));
    await ref.update({ reviewEmailSentAt: Date.now(), reviewEmailDueAt: admin.firestore.FieldValue.delete() });
    return res.json({ result: { ok: true, to } });
  } catch (e) {
    console.error("adminSendReviewEmail:", e.response?.data || e.message);
    return res.status(500).json({ error: "Erro ao enviar e-mail" });
  }
});

// Automático: a cada 15 min envia os e-mails vencidos (marcados ao concluir, ~45 min depois).
exports.sendReviewEmails = onSchedule(
  { cpu: "gcf_gen1", region: "southamerica-east1", schedule: "every 15 minutes", timeZone: "America/Sao_Paulo", secrets: [RESEND_SECRET] },
  async () => {
    const db = admin.firestore();
    const snap = await db.collection("appointments").where("reviewEmailDueAt", "<=", Date.now()).limit(50).get();
    let sent = 0;
    for (const doc of snap.docs) {
      const a = doc.data();
      const clear = { reviewEmailDueAt: admin.firestore.FieldValue.delete() };
      const rated = typeof a.rating === "number" && a.rating > 0;
      try {
        const to = a.status === "completed" && !rated && !a.reviewEmailSentAt ? await tutorEmail(a) : "";
        if (!to) { await doc.ref.update(clear); continue; }
        await sendReviewEmail(RESEND_SECRET.value(), to, a, await ensureLink(doc.id));
        await doc.ref.update({ ...clear, reviewEmailSentAt: Date.now() });
        sent++;
      } catch (e) {
        console.error("sendReviewEmails", doc.id, e.response?.data || e.message); // tenta de novo no próximo ciclo
      }
    }
    console.log(`sendReviewEmails: ${sent} e-mail(s) enviado(s).`);
  }
);
