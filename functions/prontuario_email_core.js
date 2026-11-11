// E-mail do prontuário para quem agendou pelo portal — Firestore, Storage e Resend.
// Regras puras e o HTML em prontuario_email_lib.js; endpoints em prontuario_email.js.
const admin = require("firebase-admin");
const axios = require("axios");
const lib = require("./prontuario_email_lib");

const FROM = "VetVem <agendamentos@mail.vetvem.com.br>";

// Serviços reais (trocados por falsos nos testes).
const realMail = {
  async send(resendKey, to, subject, html, attachments) {
    await axios.post(
      "https://api.resend.com/emails",
      { from: FROM, to: [to], subject, html, ...(attachments && attachments.length ? { attachments } : {}) },
      { headers: { Authorization: `Bearer ${resendKey}` } }
    );
  },
};
const realStorage = {
  async download(path) {
    const [buf] = await admin.storage().bucket().file(path).download();
    return buf;
  },
  async signedUrl(path) {
    const [url] = await admin.storage().bucket().file(path).getSignedUrl({ action: "read", expires: Date.now() + 7 * 24 * 3600 * 1000 });
    return url;
  },
};

// Anexa o que couber em MAX_ATTACH_BYTES; o resto vira link de 7 dias; o que falhar é avisado.
async function gatherAttachments(anexos, storage) {
  const files = []; const links = []; const failed = []; const used = new Set();
  let total = 0;
  for (const it of anexos) {
    if (!it || !it.path) continue;
    try {
      const buf = await storage.download(it.path);
      if (total + buf.length <= lib.MAX_ATTACH_BYTES) {
        let name = lib.safeName(it.name); let n = 1;
        while (used.has(name)) name = `${n++}_${lib.safeName(it.name)}`;
        used.add(name);
        files.push({ filename: name, content: buf.toString("base64") });
        total += buf.length;
      } else {
        links.push({ name: it.name, url: await storage.signedUrl(it.path) });
      }
    } catch (e) {
      console.warn("prontuario_email anexo:", it.path, e.message);
      failed.push(it.name || "arquivo");
    }
  }
  return { files, links, failed };
}

async function buildAndSend({ appt, mode, to, resendKey, mail, storage }) {
  const att = await gatherAttachments(lib.anexosFor(appt, mode), storage);
  const { subject, html } = lib.buildEmail(appt, mode, { links: att.links, failed: att.failed });
  await mail.send(resendKey, to, subject, html, att.files);
  return { attached: att.files.length, links: att.links.length, failed: att.failed.length };
}

// Gatilho: pedido atualizado. Reserva o envio dentro de uma transação (evita e-mail duplicado
// se o documento mudar duas vezes seguidas), envia e, se falhar, desfaz a reserva.
async function handleUpdate({ ref, resendKey, mail = realMail, storage = realStorage }) {
  let mode = null; let appt = null;
  await admin.firestore().runTransaction(async (tx) => {
    const cur = (await tx.get(ref)).data();
    mode = lib.decide(cur);
    appt = cur;
    if (!mode) return;
    tx.update(ref, mode === "full"
      ? { prontuarioEmailSentAt: Date.now(), prontuarioEmailComplements: (Array.isArray(cur.complementos) ? cur.complementos : []).length }
      : { prontuarioEmailComplements: (Array.isArray(cur.complementos) ? cur.complementos : []).length });
  });
  if (!mode) return { sent: false };
  try {
    const r = await buildAndSend({ appt, mode, to: String(appt.email).trim(), resendKey, mail, storage });
    return { sent: true, mode, ...r };
  } catch (e) {
    console.error("prontuario_email envio:", e.response?.data || e.message);
    // devolve a reserva para o próximo evento tentar de novo
    await ref.update(mode === "full"
      ? { prontuarioEmailSentAt: admin.firestore.FieldValue.delete(), prontuarioEmailComplements: admin.firestore.FieldValue.delete() }
      : { prontuarioEmailComplements: Number(appt.prontuarioEmailComplements || 0) });
    return { sent: false, error: true };
  }
}

// Reenvio pelo suporte (painel): manda o prontuário completo agora, de qualquer origem.
async function resendFull({ appt, to, resendKey, mail = realMail, storage = realStorage }) {
  return buildAndSend({ appt, mode: "full", to, resendKey, mail, storage });
}

module.exports = { handleUpdate, resendFull, gatherAttachments };
