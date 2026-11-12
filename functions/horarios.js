// Sugestão de novos horários (profissional -> tutor). Estados do pedido, só
// alterados aqui (Admin SDK; as regras do Firestore bloqueiam o cliente):
//   proposalStatus: awaiting_tutor | accepted | declined | expired
//   proposals: [{date,time}], proposalDeadline (ms), originalDate/originalTime.
// O estorno de "declined"/"expired" é feito pelo appointmentHistorian ao ver
// status = rejected (mesmo caminho de recusa/timeout que já existe).
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { validateOptions, computeDeadline, formatDeadline, parseDateTimeMs } = require("./horarios_lib");
const { petLabel } = require("./appointment_amount");
const { startRelocation } = require("./realocacao_core");
const { ORS_SECRET, AWESOME_SECRET } = require("./travel_core");
const { defineSecret } = require("firebase-functions/params");

const RESEND_SECRET = defineSecret("RESEND_API_KEY");
const resendKeyOrNull = () => { try { return RESEND_SECRET.value() || null; } catch (_) { return null; } };

const HIST_FIELD = "historico_status";

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

// Evento do funil (idempotente por status), no mesmo formato do appointmentHistorian.
async function appendHist(ref, status, origem, profissionalId, motivo) {
  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return;
    const list = Array.isArray(snap.data()[HIST_FIELD]) ? snap.data()[HIST_FIELD] : [];
    if (list.some((e) => e && e.status === status)) return;
    tx.update(ref, {
      [HIST_FIELD]: [...list, {
        status, timestamp: admin.firestore.Timestamp.now(), origem,
        profissional_id: profissionalId || null, ...(motivo ? { motivo } : {}),
      }],
    });
  });
}

function notify(uid, title, body, extra) {
  if (!uid) return Promise.resolve();
  return admin.firestore().collection("notifications").doc(uid).collection("pending").add({
    title, body, read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(), ...extra,
  });
}

// Horário já ocupado por OUTRO pedido ativo do mesmo profissional?
async function slotTaken(vetId, date, time, exceptId) {
  const snap = await admin.firestore().collection("appointments")
    .where("vetId", "==", vetId).where("date", "==", date).where("time", "==", time).get();
  return snap.docs.some((d) => {
    if (d.id === exceptId) return false;
    const s = d.data().status;
    return s === "pending_confirmation" || s === "confirmed";
  });
}

// ── Profissional sugere até 3 horários ───────────────────────────────────────
exports.proposeNewTimes = onRequest({ region: "southamerica-east1", cors: false }, async (req, res) => {
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });
  const uid = await authUid(req, res);
  if (!uid) return;
  const { appointmentId, options } = req.body || {};
  if (!appointmentId) return res.status(400).json({ error: "Pedido não informado." });

  const ref = admin.firestore().collection("appointments").doc(String(appointmentId));
  const appt = (await ref.get()).data();
  if (!appt) return res.status(404).json({ error: "Pedido não encontrado." });
  if (appt.vetId !== uid) return res.status(403).json({ error: "Este pedido não é seu." });
  if (appt.status !== "pending_confirmation" || appt.paymentStatus !== "approved") {
    return res.status(409).json({ error: "Este pedido não está aguardando a sua resposta." });
  }
  if (appt.bookingOrigin === "portal_web" || appt.canChooseTimes !== true) {
    return res.status(409).json({ error: "Este pedido não permite sugerir outros horários. Aceite ou recuse." });
  }
  if (appt.proposalStatus) {
    return res.status(409).json({ error: "Você já enviou sugestões para este pedido." });
  }

  const now = Date.now();
  const v = validateOptions(options, appt, now);
  if (!v.ok) return res.status(400).json({ error: v.error });

  for (const o of v.options) {
    if (await slotTaken(uid, o.date, o.time, ref.id)) {
      return res.status(409).json({ error: `Você já tem um atendimento em ${o.date} às ${o.time}.` });
    }
  }

  const deadline = computeDeadline(now, v.options[0].ms);
  await ref.update({
    proposalStatus: "awaiting_tutor",
    proposals: v.options.map((o) => ({ date: o.date, time: o.time })),
    proposalSentAt: admin.firestore.FieldValue.serverTimestamp(),
    proposalDeadline: deadline,
    originalDate: appt.date,
    originalTime: appt.time,
  });
  await appendHist(ref, "horarios_sugeridos", "app_pro", uid, null);

  await notify(appt.tutorId, "🗓️ Novos horários sugeridos",
    `${appt.vetName || "O profissional"} não consegue atender em ${appt.date} às ${appt.time} para ${petLabel(appt, "seu pet")}. ` +
    `Escolha uma das opções até ${formatDeadline(deadline)}; se nenhuma servir, o valor é devolvido.`,
    { tipo: "horarios_sugeridos", appointmentId: ref.id });

  return res.json({ ok: true, deadline, options: v.options.map((o) => ({ date: o.date, time: o.time })) });
});

// ── Tutor escolhe um horário (choice = 0..2) ou recusa todos (choice = "none") ─
exports.respondToProposal = onRequest({ region: "southamerica-east1", cors: false, secrets: [RESEND_SECRET, ORS_SECRET, AWESOME_SECRET] }, async (req, res) => {
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });
  const uid = await authUid(req, res);
  if (!uid) return;
  const { appointmentId, choice } = req.body || {};
  if (!appointmentId) return res.status(400).json({ error: "Pedido não informado." });

  const ref = admin.firestore().collection("appointments").doc(String(appointmentId));
  const appt = (await ref.get()).data();
  if (!appt) return res.status(404).json({ error: "Pedido não encontrado." });
  if (appt.tutorId !== uid) return res.status(403).json({ error: "Este pedido não é seu." });
  if (appt.status !== "pending_confirmation" || appt.proposalStatus !== "awaiting_tutor") {
    return res.status(409).json({ error: "Não há sugestões de horário para responder neste pedido." });
  }
  if (Date.now() > Number(appt.proposalDeadline || 0)) {
    return res.status(410).json({ error: "O prazo para escolher terminou." });
  }

  if (choice === "none" || choice === "cancel") {
    // Nenhum horário serve: antes de estornar, oferece outros profissionais para o
    // mesmo dia e horário (se o app do tutor suporta e houver quem atenda).
    // "cancel" = o tutor prefere cancelar: estorno total, sem oferecer outros profissionais.
    const relocated = choice === "none"
      ? await startRelocation(ref, appt, { resendKey: resendKeyOrNull() })
      : false;
    if (relocated) {
      await notify(appt.vetId, "Tutor não pôde nos horários sugeridos",
        `O tutor de ${petLabel(appt, "um pet")} não pôde em nenhum dos horários sugeridos. O pedido foi oferecido a outros profissionais.`,
        { tipo: "proposta_recusada", appointmentId: ref.id });
      return res.json({ ok: true, declined: false, relocation: true });
    }
    await ref.update({
      status: "rejected",
      rejectReason: "tutor_no_option",
      rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
      proposalStatus: "declined",
    });
    await notify(appt.vetId, "Tutor não escolheu novo horário",
      `O tutor de ${petLabel(appt, "um pet")} não pôde em nenhum dos horários sugeridos. O pedido foi encerrado e o valor devolvido.`,
      { tipo: "proposta_recusada", appointmentId: ref.id });
    return res.json({ ok: true, declined: true });
  }

  const idx = Number.isInteger(choice) ? choice : parseInt(choice, 10);
  const proposals = Array.isArray(appt.proposals) ? appt.proposals : [];
  const pick = proposals[idx];
  if (!pick) return res.status(400).json({ error: "Horário inválido." });
  if (parseDateTimeMs(pick.date, pick.time) <= Date.now()) {
    return res.status(410).json({ error: "Esse horário já passou." });
  }
  if (await slotTaken(appt.vetId, pick.date, pick.time, ref.id)) {
    return res.status(409).json({ error: "Esse horário acabou de ser ocupado. Escolha outro." });
  }

  await ref.update({
    date: pick.date,
    time: pick.time,
    status: "confirmed",
    confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
    proposalStatus: "accepted",
    chosenIndex: idx,
  });
  await appendHist(ref, "horario_escolhido", "app_tutor", appt.vetId, `${pick.date} ${pick.time}`);
  await notify(appt.vetId, "✅ Horário confirmado pelo tutor",
    `O tutor escolheu ${pick.date} às ${pick.time} para ${petLabel(appt, "o pet")}. A consulta está confirmada.`,
    { tipo: "horario_confirmado", appointmentId: ref.id });
  return res.json({ ok: true, date: pick.date, time: pick.time });
});

// ── Prazo do tutor terminou sem resposta: encerra e estorna ──────────────────
exports.expireProposals = onSchedule(
  { cpu: "gcf_gen1", schedule: "*/5 * * * *", timeZone: "America/Sao_Paulo", region: "southamerica-east1" },
  async () => {
    const db = admin.firestore();
    const now = Date.now();
    const snap = await db.collection("appointments")
      .where("status", "==", "pending_confirmation")
      .where("proposalStatus", "==", "awaiting_tutor").get();
    let n = 0;
    for (const doc of snap.docs) {
      const d = doc.data();
      if (Number(d.proposalDeadline || 0) > now) continue;
      await doc.ref.update({
        status: "rejected",
        rejectReason: "proposal_expired",
        rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
        proposalStatus: "expired",
      });
      n++;
      const pet = petLabel(d, "seu pet");
      await Promise.all([
        notify(d.tutorId, "⏰ Prazo dos novos horários terminou",
          `Você não escolheu um dos horários sugeridos para ${pet}. O pedido foi encerrado e o valor será estornado.`,
          { tipo: "proposta_expirada", appointmentId: doc.id }),
        notify(d.vetId, "⏰ Tutor não respondeu aos horários",
          `O tutor de ${pet} não escolheu um horário no prazo. O pedido foi encerrado.`,
          { tipo: "proposta_expirada", appointmentId: doc.id }),
      ]);
    }
    console.log(`expireProposals: ${n} sugestão(ões) expirada(s).`);
  }
);
