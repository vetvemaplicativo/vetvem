// Realocação de profissional — operações no Firestore (NÃO exporta Cloud Functions:
// os endpoints ficam em realocacao.js). Quando o veterinário recusa ou não responde,
// o pedido (já pago) fica com o tutor, que escolhe outro profissional para o MESMO
// dia e horário, com preço igual ou menor. Estados em appointments/{id}.relocationStatus:
//   awaiting_tutor : tutor escolhendo (relocationOptions, relocationDeadline)
//   awaiting_vet   : tutor escolheu; o novo profissional tem até responseDeadline
//   done           : o novo profissional aceitou (estorno da diferença, se houver)
//   declined/expired : tutor desistiu / não escolheu no prazo (estorno total pelo historiador)
// Só as Cloud Functions escrevem esses campos (regras do Firestore bloqueiam o cliente).
const admin = require("firebase-admin");
const axios = require("axios");
const L = require("./realocacao_lib");
const { petLabel, toNum } = require("./appointment_amount");
const { parseDateTimeMs } = require("./horarios_lib");

const HIST_FIELD = "historico_status";
const ADMIN_EMAIL = "ronalddesouzabr@gmail.com";
const FV = () => admin.firestore.FieldValue;

function notify(uid, title, body, extra) {
  if (!uid) return Promise.resolve();
  return admin.firestore().collection("notifications").doc(uid).collection("pending").add({
    title, body, read: false, createdAt: FV().serverTimestamp(), ...extra,
  });
}

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

async function sendMail(resendKey, to, subject, html) {
  await axios.post(
    "https://api.resend.com/emails",
    { from: "VetVem <agendamentos@mail.vetvem.com.br>", to: [to], subject, html },
    { headers: { Authorization: `Bearer ${resendKey}` } }
  );
}

// Horário já ocupado por OUTRO pedido ativo do profissional?
async function slotTaken(vetId, date, time, exceptId) {
  const snap = await admin.firestore().collection("appointments")
    .where("vetId", "==", vetId).where("date", "==", date).where("time", "==", time).get();
  return snap.docs.some((d) => {
    if (d.id === exceptId) return false;
    const s = d.data().status;
    return s === "pending_confirmation" || s === "confirmed";
  });
}

// Lista de profissionais que podem assumir o pedido: mesma região, mesma
// especialidade, serviço parecido, trabalham naquele dia/horário, agenda livre e
// preço igual ou menor ao valor pago. onlyVetId = confere só esse profissional.
async function findCandidates(appt, apptId, onlyVetId) {
  const db = admin.firestore();
  const origVetId = appt.originalVetId || appt.vetId || "";
  const tried = new Set([...(appt.relocationTried || []), appt.vetId, appt.originalVetId].filter(Boolean));
  const origService = appt.originalServiceName || appt.serviceName || "";
  const maxAmount = L.paidAmount(appt);

  const origPub = origVetId ? (await db.collection("professionals_public").doc(origVetId).get()).data() : null;
  const snap = await db.collection("professionals_public").get();

  const pre = [];
  for (const doc of snap.docs) {
    const id = doc.id;
    if (onlyVetId ? id !== onlyVetId : tried.has(id)) continue;
    if (id === appt.tutorId) continue;
    const pub = doc.data() || {};
    if (pub.isAvailable === false) continue;
    if (!L.sharesCategory(origPub && origPub.categories, pub.categories)) continue;
    if (!L.coversAddress(pub.area_atuacao, appt.addrUf, appt.addrCity, appt.addrNeighborhood)) continue;
    if (!L.worksAt(pub, appt.date, appt.time)) continue;
    const svc = L.pickService(pub.services, origService, appt, maxAmount);
    if (!svc) continue;
    pre.push({
      vetId: id, vetName: String(pub.name || ""), crmv: String(pub.crmv || ""),
      serviceName: svc.name, price: svc.amount, travel: svc.travel, rating: Number(pub.rating) || 0,
    });
  }
  // agenda livre (conferida só para quem passou nos filtros baratos)
  const free = [];
  for (const c of pre) {
    if (!(await slotTaken(c.vetId, appt.date, appt.time, apptId))) free.push(c);
  }
  return L.rankCandidates(free).map(({ rating, ...rest }) => rest); // eslint-disable-line no-unused-vars
}

// Tenta abrir a realocação. Retorna true se o pedido ficou com o tutor escolhendo
// (nesse caso NÃO se deve estornar), false se não dá (o chamador estorna como antes).
// deps: { resendKey } (e-mail opcional).
async function startRelocation(ref, appt, deps = {}) {
  const now = Date.now();
  const chk = L.canRelocate(appt, now);
  if (!chk.ok) return false;
  let options;
  try {
    options = await findCandidates(appt, ref.id);
  } catch (e) {
    console.error("startRelocation findCandidates:", e.message);
    return false;
  }
  if (options.length === 0) return false;

  const prevVet = appt.vetId || "";
  const prevVetName = appt.vetName || "o profissional";
  const tried = [...new Set([...(appt.relocationTried || []), prevVet].filter(Boolean))];
  const first = !appt.originalVetId;
  const deadline = L.tutorDeadline(now);
  await ref.update({
    status: "pending_confirmation",
    relocationStatus: "awaiting_tutor",
    relocationOptions: options,
    relocationDeadline: deadline,
    relocationRound: (Number(appt.relocationRound) || 0) + 1,
    relocationTried: tried,
    ...(first ? {
      originalVetId: prevVet,
      originalVetName: prevVetName,
      originalServiceName: appt.serviceName || "",
      originalValue: L.paidAmount(appt),
    } : {}),
    vetId: "", // sai da fila do profissional que recusou/não respondeu
    // O Pro lista os pedidos por vetName: sem trocar o nome, o pedido continuaria na fila (com
    // Aceitar/Recusar) do profissional que recusou/não respondeu.
    vetName: "Escolhendo outro profissional",
    // se o profissional tinha sugerido horários e o tutor disse "nenhum serve", encerra a sugestão
    ...(appt.proposalStatus === "awaiting_tutor" ? { proposalStatus: "declined" } : {}),
    rejectReason: FV().delete(),
    rejectedAt: FV().delete(),
    responseDeadline: FV().delete(),
    relocationAttempted: FV().delete(),
  });
  await appendHist(ref, "realocacao_oferecida", "cloud_function", prevVet, null);

  const pet = petLabel(appt, "seu pet");
  const when = `${appt.date} às ${appt.time}`;
  const until = L.formatDeadline(deadline);
  await notify(appt.tutorId, "🔄 Escolha outro profissional",
    `${prevVetName} não pôde atender ${pet} em ${when}. Veja quem atende no mesmo dia e horário e escolha até ${until}. O valor pago continua reservado: nada foi cobrado a mais.`,
    { tipo: "realocacao", appointmentId: ref.id });

  // Se o profissional simplesmente não respondeu, avisa que o pedido foi oferecido a outros.
  if (appt.rejectReason === "no_response" && prevVet) {
    await notify(prevVet, "⏰ Solicitação oferecida a outros profissionais",
      `A solicitação de ${pet} (${when}) ficou sem resposta e foi oferecida a outros profissionais.`,
      { tipo: "consulta_expirada", appointmentId: ref.id });
  }

  // E-mail ao tutor (quem fecha o app pode não ver o push).
  if (deps.resendKey && appt.tutorId) {
    try {
      const user = await admin.auth().getUser(appt.tutorId);
      if (user && user.email) {
        await sendMail(deps.resendKey, user.email, "Escolha outro profissional para a sua consulta 🐾",
          `<p>Olá${appt.tutorName ? ", " + appt.tutorName : ""}!</p>
           <p><strong>${prevVetName}</strong> não pôde atender ${pet} em ${when}.</p>
           <p>Há <strong>${options.length}</strong> profissional(is) disponível(is) no mesmo dia e horário. Abra o app VetVem e escolha até <strong>${until}</strong>.</p>
           <p>O valor que você pagou continua reservado. Se o novo valor for menor, a diferença é devolvida. Se nenhum servir, você pode pedir o estorno total no próprio app.</p>`);
      }
    } catch (e) {
      console.error("startRelocation email:", (e.response && e.response.data) || e.message);
    }
  }
  return true;
}

// Trava curta para dois tutores não pegarem o mesmo horário do mesmo profissional ao mesmo tempo.
async function takeSlotLock(vetId, date, time, apptId) {
  const db = admin.firestore();
  const key = `${vetId}|${date.replace(/\//g, "-")}|${time.replace(":", "")}`;
  const ref = db.collection("relocation_locks").doc(key);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const cur = snap.exists ? snap.data() : null;
    if (cur && cur.apptId !== apptId && Date.now() - Number(cur.at || 0) < 2 * 60 * 1000) return false;
    tx.set(ref, { apptId, at: Date.now() });
    return true;
  });
}

// Tutor escolheu um profissional. Retorna { ok:true, ... } ou { ok:false, code, error }.
async function chooseVet(ref, appt, vetId) {
  const now = Date.now();
  if (appt.status !== "pending_confirmation" || appt.relocationStatus !== "awaiting_tutor") {
    return { ok: false, code: 409, error: "Não há profissionais para escolher neste pedido." };
  }
  if (now > Number(appt.relocationDeadline || 0)) {
    return { ok: false, code: 410, error: "O prazo para escolher terminou." };
  }
  const listed = (appt.relocationOptions || []).find((o) => o.vetId === vetId);
  if (!listed) return { ok: false, code: 400, error: "Profissional inválido." };
  const apptMs = parseDateTimeMs(appt.date, appt.time);
  if (apptMs === null || apptMs - now < 90 * 60 * 1000) {
    return { ok: false, code: 410, error: "Falta pouco tempo para a consulta." };
  }

  // Reconfere tudo na hora: o profissional pode ter ficado indisponível.
  const fresh = await findCandidates(appt, ref.id, vetId);
  const pick = fresh[0];
  if (!pick) {
    await ref.update({ relocationOptions: (appt.relocationOptions || []).filter((o) => o.vetId !== vetId) });
    return { ok: false, code: 409, error: "Esse profissional acabou de ficar indisponível. Escolha outro." };
  }
  if (!(await takeSlotLock(pick.vetId, appt.date, appt.time, ref.id))) {
    return { ok: false, code: 409, error: "Esse horário acabou de ser reservado por outro tutor. Escolha outro profissional." };
  }
  if (await slotTaken(pick.vetId, appt.date, appt.time, ref.id)) {
    return { ok: false, code: 409, error: "Esse horário acabou de ser ocupado. Escolha outro profissional." };
  }

  const vetDeadline = L.vetDeadline(now, apptMs);
  await ref.update({
    vetId: pick.vetId,
    vetName: pick.vetName,
    serviceName: pick.serviceName,
    value: L.moneyString(pick.price),
    travelFee: pick.travel > 0 ? pick.travel : FV().delete(),
    status: "pending_confirmation",
    relocationStatus: "awaiting_vet",
    responseDeadline: vetDeadline,
    relocationChosenAt: FV().serverTimestamp(),
    vetNotifiedAt: FV().serverTimestamp(),
    viewedAt: FV().delete(),
    relocationOptions: FV().delete(),
    relocationDeadline: FV().delete(),
    proposalStatus: FV().delete(),
    proposals: FV().delete(),
    proposalSentAt: FV().delete(),
    proposalDeadline: FV().delete(),
    originalDate: FV().delete(),
    originalTime: FV().delete(),
    chosenIndex: FV().delete(),
    instructionsText: FV().delete(),
    instructionsSentAt: FV().delete(),
  });
  await appendHist(ref, "aguardando_confirmacao_novo_profissional", "app_tutor", pick.vetId, null);

  const pet = petLabel(appt, "o pet");
  const until = L.formatDeadline(vetDeadline);
  await notify(pick.vetId, "🗓️ Novo agendamento pago!",
    `${appt.tutorName || "Um tutor"} agendou ${pick.serviceName || "uma consulta"} para ${pet} em ${appt.date} às ${appt.time}. Confirme até ${until} ou a solicitação expira.`,
    { tipo: "novo_agendamento", appointmentId: ref.id });
  await notify(appt.tutorId, "📨 Pedido enviado ao novo profissional",
    `${pick.vetName} recebeu o seu pedido para ${appt.date} às ${appt.time} e tem até ${until} para confirmar.`,
    { tipo: "realocacao_enviada", appointmentId: ref.id });

  return { ok: true, vetName: pick.vetName, price: pick.price, deadline: vetDeadline };
}

// O novo profissional aceitou: devolve a diferença de preço (se houver) por estorno
// parcial e acerta o valor do pedido (comissão/repasse usam paymentAmount).
async function settleRelocation(ref, appt, deps = {}) {
  const original = toNum(appt.originalValue) || L.paidAmount(appt);
  const finalAmt = toNum(appt.value);
  const diff = Math.round((original - finalAmt) * 100) / 100;
  let refunded = 0;
  let pending = false;
  if (diff > 0.009 && appt.paymentId && deps.mpToken) {
    try {
      await axios.post(
        `https://api.mercadopago.com/v1/payments/${appt.paymentId}/refunds`,
        { amount: diff },
        { headers: { Authorization: `Bearer ${deps.mpToken}`, "X-Idempotency-Key": `relocation-refund-${ref.id}` } }
      );
      refunded = diff;
    } catch (e) {
      pending = true;
      const err = (e.response && e.response.data) || e.message;
      console.error("settleRelocation refund:", err);
      if (deps.resendKey) {
        try {
          await sendMail(deps.resendKey, ADMIN_EMAIL, `⚠️ Estorno parcial falhou — ${ref.id}`,
            `<p>Realocação do agendamento ${ref.id}: devolver R$ ${diff.toFixed(2)} ao tutor (paymentId ${appt.paymentId}).</p>
             <p>Erro: ${JSON.stringify(err)}</p><p>Estornar manualmente no painel do Mercado Pago.</p>`);
        } catch (e2) { console.error("settleRelocation admin mail:", e2.message); }
      }
    }
  }
  await ref.update({
    relocationStatus: "done",
    paymentAmount: finalAmt > 0 ? finalAmt : original,
    ...(refunded > 0 ? { relocationRefund: refunded, relocationRefundedAt: FV().serverTimestamp() } : {}),
    ...(pending ? { relocationRefundPending: diff } : {}),
  });
  await appendHist(ref, "reagendado_com_outro_profissional", "app_pro", appt.vetId, null);
  if (appt.tutorId) {
    await notify(appt.tutorId, "✅ Consulta confirmada com outro profissional",
      `${appt.vetName || "O profissional"} confirmou a consulta de ${petLabel(appt, "seu pet")} em ${appt.date} às ${appt.time}.` +
      (refunded > 0 ? ` Devolvemos a diferença de R$ ${refunded.toFixed(2).replace(".", ",")} (valor menor).` : ""),
      { tipo: "realocacao_confirmada", appointmentId: ref.id });
  }
}

module.exports = {
  findCandidates, startRelocation, chooseVet, settleRelocation, slotTaken, notify, appendHist,
};
