// Lembretes de consulta (profissional e tutor). Regras de prazo/texto em lembretes_lib.js.
// Roda a cada 15 min, olha as consultas confirmadas e pagas e envia o aviso que estiver no prazo.
// A notificação vai para notifications/{uid}/pending (a função sendPush entrega o push). Quem
// agendou pelo portal não tem o app: recebe o lembrete da véspera por e-mail.
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const axios = require("axios");
const L = require("./lembretes_lib");
const { petLabel } = require("./appointment_amount");

const RESEND_SECRET = defineSecret("RESEND_API_KEY");
const resendKeyOrNull = () => { try { return RESEND_SECRET.value() || null; } catch (_) { return null; } };

const esc = (s) => String(s || "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

function notify(uid, title, body, extra) {
  if (!uid) return Promise.resolve();
  return admin.firestore().collection("notifications").doc(uid).collection("pending").add({
    title, body, read: false, createdAt: admin.firestore.FieldValue.serverTimestamp(), ...extra,
  });
}

async function sendMail(resendKey, to, subject, html) {
  await axios.post(
    "https://api.resend.com/emails",
    { from: "VetVem <agendamentos@mail.vetvem.com.br>", to: [to], subject, html },
    { headers: { Authorization: `Bearer ${resendKey}` } }
  );
}

// Envia os lembretes de uma consulta que estão no prazo. Retorna as chaves enviadas.
async function sendDueReminders(doc, now, resendKey) {
  const appt = doc.data();
  const due = L.remindersDue(appt, now);
  const sent = [];
  for (const key of due) {
    // marca antes de enviar: melhor perder um aviso do que duplicar
    await doc.ref.update({ [`remindersSent.${key}`]: admin.firestore.FieldValue.serverTimestamp() });
    const msg = L.buildMessage(key, appt, petLabel(appt, "seu pet"));
    const aud = L.AUDIENCE[key];
    const extra = { tipo: "lembrete", appointmentId: doc.id };
    try {
      if (aud === "vet") {
        await notify(appt.vetId, msg.title, msg.body, extra);
      } else {
        const portal = appt.bookingOrigin === "portal_web";
        if (!portal) await notify(appt.tutorId, msg.title, msg.body, extra);
        // Portal não tem push: e-mail na véspera. App: o push basta.
        if (portal && key === "tutor_1d" && resendKey && appt.email) {
          await sendMail(resendKey, appt.email, msg.title,
            `<p>Olá${appt.tutorName ? `, ${esc(String(appt.tutorName).trim().split(" ")[0])}` : ""}!</p>` +
            `<p>${esc(msg.body)}</p><p>Equipe VetVem 🐾</p>`);
        }
      }
      sent.push(key);
    } catch (e) {
      console.error(`lembretes: falha ao enviar ${key} de ${doc.id}:`, e.message);
    }
  }
  return sent;
}

exports.consultaLembretes = onSchedule(
  { schedule: "*/15 * * * *", timeZone: "America/Sao_Paulo", region: "southamerica-east1", secrets: [RESEND_SECRET] },
  async () => {
    const now = new Date();
    const snap = await admin.firestore().collection("appointments")
      .where("status", "==", "confirmed").get();
    const resendKey = resendKeyOrNull();
    let total = 0;
    for (const doc of snap.docs) {
      total += (await sendDueReminders(doc, now, resendKey)).length;
    }
    console.log(`consultaLembretes: ${total} lembrete(s) enviado(s).`);
  }
);
