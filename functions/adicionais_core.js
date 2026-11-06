// Adicionais durante o atendimento — operações no Firestore e no Mercado Pago.
// Regras puras em adicionais_lib.js; endpoints/agendamento em adicionais.js.
//
//   createCharge        fecha o rascunho e gera o PIX (30 min) com o total dos itens
//   cancelExtra         profissional desiste do rascunho/da cobrança pendente
//   settleExtraPayment  webhook do MP (external_reference "add:{pedido}:{extra}")
//   processExtraPayouts repasses D+2 a partir do pagamento (extra_payouts_queue -> payouts)
const admin = require("firebase-admin");
const axios = require("axios");
const { accountOf, tokenOf, withAccountFallback } = require("./mp_accounts");
const { petLabel } = require("./appointment_amount");
const { parseDateTimeMs } = require("./horarios_lib");
const lib = require("./adicionais_lib");
const fees = require("./payout_fees");

const PIX_HOLD_HOURS = 48; // mesma carência do dailyPayouts após trocar a chave PIX
const FV = () => admin.firestore.FieldValue;
const db = () => admin.firestore();
const brl = (n) => `R$ ${Number(n).toFixed(2).replace(".", ",")}`;

const extraDoc = (apptId, extraId) =>
  db().collection("appointments").doc(apptId).collection("extras").doc(extraId);

// Mesma regra de index.js: a conta nova se identifica por ?acc=v2.
function webhookUrl(account) {
  return `https://southamerica-east1-vetvem-18bf4.cloudfunctions.net/mpWebhook${account === "v2" ? "?acc=v2" : ""}`;
}

function notify(uid, title, body, extra) {
  if (!uid) return Promise.resolve();
  return db().collection("notifications").doc(uid).collection("pending").add({
    title, body, read: false, createdAt: FV().serverTimestamp(), ...extra,
  });
}

// Chamadas reais ao Mercado Pago (trocadas por falsas nos testes).
const realMp = {
  async createPix(account, body, idempotencyKey) {
    const r = await axios.post("https://api.mercadopago.com/v1/payments", body, {
      headers: { Authorization: `Bearer ${tokenOf(account)}`, "Content-Type": "application/json", "X-Idempotency-Key": idempotencyKey },
    });
    return r.data;
  },
  async cancelPayment(account, paymentId) {
    await axios.put(`https://api.mercadopago.com/v1/payments/${paymentId}`, { status: "cancelled" }, {
      headers: { Authorization: `Bearer ${tokenOf(account)}`, "Content-Type": "application/json" },
    });
  },
};

// E-mail do pagador (o MP exige um): pedido → perfil → Auth → endereço próprio do VetVem.
async function payerOf(appt, apptId) {
  let email = String(appt.email || "").trim();
  if (!email && appt.tutorId) {
    try { email = String(((await db().collection("users").doc(appt.tutorId).get()).data() || {}).email || "").trim(); } catch (_) {}
  }
  if (!email && appt.tutorId) {
    try { email = String((await admin.auth().getUser(appt.tutorId)).email || "").trim(); } catch (_) {}
  }
  if (!email) email = `adicional+${apptId}@vetvem.com.br`;
  const parts = String(appt.tutorName || "").trim().split(/\s+/).filter(Boolean);
  return { email, firstName: parts[0] || "Cliente", lastName: parts.slice(1).join(" ") || "VetVem" };
}

// ── Gerar o PIX ─────────────────────────────────────────────────────────────
async function createCharge({ appointmentId, extraId, uid, nowMs = Date.now(), mp = realMp }) {
  const apptRef = db().collection("appointments").doc(appointmentId);
  const appt = (await apptRef.get()).data();
  if (!appt) return { ok: false, code: 404, error: "Pedido não encontrado." };
  if (appt.vetId !== uid) return { ok: false, code: 403, error: "Este pedido não é seu." };

  const ws = lib.windowState(appt, parseDateTimeMs(appt.date, appt.time), nowMs);
  if (!ws.open) return { ok: false, code: 422, error: ws.reason };

  const ref = extraDoc(appointmentId, extraId);
  const extra = (await ref.get()).data();
  if (!extra) return { ok: false, code: 404, error: "Adicional não encontrado." };
  if (extra.status === "paid") return { ok: false, code: 409, error: "Este adicional já foi pago." };
  if (extra.status === "cancelled") return { ok: false, code: 409, error: "Este adicional foi cancelado." };

  // Voltou à tela com o PIX ainda válido: devolve o mesmo (evita cobrança dupla).
  if (extra.status === "awaiting_payment" && extra.pixCopyPaste && extra.pixExpiresAt > nowMs + 60 * 1000) {
    return { ok: true, result: pixResult(extra) };
  }

  const cleaned = lib.cleanItems(extra.items);
  if (cleaned.error) return { ok: false, code: 422, error: cleaned.error };

  const pixExpiresAt = nowMs + lib.PIX_MINUTES * 60 * 1000;
  const payer = await payerOf(appt, appointmentId);
  const own = accountOf(appt);
  const order = own === "v2" ? ["v2", "v1"] : ["v1", "v2"]; // começa pela conta que recebeu o pedido
  let payment; let account;
  try {
    const r = await withAccountFallback(order, (acc) => mp.createPix(acc, {
      transaction_amount: cleaned.total,
      description: `Adicionais da consulta - ${petLabel(appt, "pet")}`,
      payment_method_id: "pix",
      payer: {
        email: payer.email, first_name: payer.firstName, last_name: payer.lastName,
        identification: { type: "CPF", number: "00000000000" },
      },
      external_reference: lib.makeRef(appointmentId, extraId),
      date_of_expiration: new Date(pixExpiresAt).toISOString(),
      notification_url: webhookUrl(acc),
    }, `extra-${extraId}-${Math.floor(nowMs / (lib.PIX_MINUTES * 60 * 1000))}`), () => true);
    payment = r.value; account = r.account;
  } catch (e) {
    const msg = (e && e.response && e.response.data && e.response.data.message) || (e && e.message) || "";
    console.error("extraCharge PIX:", JSON.stringify((e && e.response && e.response.data) || msg));
    return { ok: false, code: 502, error: msg || "Não foi possível gerar o PIX agora." };
  }

  const pix = (payment.point_of_interaction || {}).transaction_data || {};
  await ref.update({
    status: "awaiting_payment",
    items: cleaned.items,
    total: cleaned.total,
    paymentAccount: account,
    paymentId: String(payment.id),
    pixCopyPaste: pix.qr_code || null,
    pixQrCodeBase64: pix.qr_code_base64 || null,
    pixExpiresAt,
    chargedAt: FV().serverTimestamp(),
  });
  return { ok: true, result: pixResult({ pixCopyPaste: pix.qr_code, pixQrCodeBase64: pix.qr_code_base64, pixExpiresAt, total: cleaned.total }) };
}

function pixResult(e) {
  return { pixCopyPaste: e.pixCopyPaste, pixQrCodeBase64: e.pixQrCodeBase64, pixExpiresAt: e.pixExpiresAt, total: e.total };
}

// ── Cancelar ────────────────────────────────────────────────────────────────
async function cancelExtra({ appointmentId, extraId, uid, mp = realMp }) {
  const appt = (await db().collection("appointments").doc(appointmentId).get()).data();
  if (!appt) return { ok: false, code: 404, error: "Pedido não encontrado." };
  if (appt.vetId !== uid) return { ok: false, code: 403, error: "Este pedido não é seu." };
  const ref = extraDoc(appointmentId, extraId);
  const extra = (await ref.get()).data();
  if (!extra) return { ok: false, code: 404, error: "Adicional não encontrado." };
  if (extra.status === "paid") return { ok: false, code: 409, error: "Este adicional já foi pago." };
  if (extra.status === "cancelled") return { ok: true };
  await ref.update({ status: "cancelled", cancelledAt: FV().serverTimestamp() });
  // PIX pendente: tenta cancelar no MP (se o tutor pagar assim mesmo, o webhook trata como pago).
  if (extra.status === "awaiting_payment" && extra.paymentId) {
    try { await mp.cancelPayment(extra.paymentAccount === "v2" ? "v2" : "v1", extra.paymentId); } catch (e) {
      console.warn("extraCancel: não cancelou o PIX no MP:", e.message);
    }
  }
  return { ok: true };
}

// ── Webhook ─────────────────────────────────────────────────────────────────
async function settleExtraPayment({ payment, account, nowMs = Date.now() }) {
  const parsed = lib.parseRef(payment.external_reference);
  if (!parsed) return { handled: false };
  const { appointmentId, extraId } = parsed;
  const ref = extraDoc(appointmentId, extraId);
  const first = (await ref.get()).data();
  if (!first) { console.warn(`settleExtraPayment: adicional ${extraId} não existe`); return { handled: true }; }

  if (payment.status === "approved") {
    if (Math.abs(Number(payment.transaction_amount) - Number(first.total)) > 0.01) {
      console.error(`settleExtraPayment: valor pago ${payment.transaction_amount} difere do total ${first.total} (${extraId})`);
      await ref.update({ paymentIssue: `valor pago ${payment.transaction_amount} difere de ${first.total}` });
      return { handled: true, mismatch: true };
    }
    // Só o primeiro webhook "approved" processa; repetições são ignoradas.
    let already = false; let afterCancel = false;
    await db().runTransaction(async (tx) => {
      const cur = (await tx.get(ref)).data() || {};
      if (cur.status === "paid") { already = true; return; }
      afterCancel = cur.status === "cancelled";
      tx.update(ref, {
        status: "paid", paidAt: FV().serverTimestamp(), paidAtMs: nowMs,
        paymentId: String(payment.id), paymentAccount: account,
        ...(afterCancel ? { paidAfterCancel: true } : {}),
      });
      tx.set(db().collection("extra_payouts_queue").doc(extraId), {
        appointmentId, extraId, vetId: first.vetId || "", gross: Number(first.total),
        paidAtMs: nowMs, dueAt: lib.payoutDueAt(nowMs), processed: false,
      });
    });
    if (already) return { handled: true, already: true };

    const appt = (await db().collection("appointments").doc(appointmentId).get()).data() || {};
    const pet = petLabel(appt, "seu pet");
    const total = brl(first.total);
    await notify(appt.tutorId, "✅ Adicionais pagos",
      `Recebemos ${total} dos adicionais da consulta de ${pet}. Veja os detalhes na consulta.`,
      { tipo: "adicional_pago", appointmentId });
    await notify(appt.vetId, "💸 Adicionais pagos",
      `${appt.tutorName || "O tutor"} pagou ${total} em adicionais da consulta de ${pet}.`,
      { tipo: "adicional_pago", appointmentId });
    return { handled: true, paid: true };
  }

  // PIX expirou/cancelado/recusado: libera o profissional para gerar outro.
  if (["cancelled", "rejected", "expired"].includes(payment.status)
      && first.status === "awaiting_payment" && first.paymentId === String(payment.id)) {
    await ref.update({ status: "expired", paymentStatusDetail: payment.status_detail || payment.status });
  }
  return { handled: true };
}

// ── Repasses ────────────────────────────────────────────────────────────────
// Repasses D+2 do PAGAMENTO do adicional. Cada adicional vira um doc em `payouts` (mesma lista e
// mesma tela do painel); appointmentId fica vazio para o painel não marcar o pedido como repassado.
async function processExtraPayouts({ nowMs = Date.now() } = {}) {
  const snap = await db().collection("extra_payouts_queue").where("processed", "==", false).get();
  const due = snap.docs.filter((d) => Number(d.data().dueAt) <= nowMs);
  if (!due.length) return { count: 0, total: 0, held: 0, lines: [] };

  const tiers = await fees.loadFeeTiers(db());
  const vetCache = {};
  const lines = []; let total = 0; let held = 0;
  for (const q of due) {
    const x = q.data();
    const vetId = x.vetId;
    if (!vetCache[vetId]) {
      const u = (await db().collection("users").doc(vetId).get()).data() || {};
      const chg = u.pixChangedAt && u.pixChangedAt.toDate ? u.pixChangedAt.toDate() : null;
      const override = fees.activeOverride(u);
      const pct = override != null ? override
        : fees.feePercentFor(await fees.lastMonthCountForVet(db(), vetId, new Date(nowMs)), tiers);
      const keys = u.pixKeys || [];
      vetCache[vetId] = {
        held: !!(chg && nowMs - chg.getTime() < PIX_HOLD_HOURS * 3600 * 1000),
        pct, name: u.name || "",
        pixKey: keys.length ? `${keys[0].key} (${keys[0].type})` : "sem chave PIX cadastrada",
      };
    }
    const v = vetCache[vetId];
    if (v.held) { held++; continue; } // entra sozinho num dia seguinte
    const appt = (await db().collection("appointments").doc(x.appointmentId).get()).data() || {};
    const line = lib.payoutLine(Number(x.gross), v.pct);
    const payoutId = `${x.appointmentId}_${x.extraId}`;
    await db().collection("payouts").doc(payoutId).set({
      appointmentId: "", parentAppointmentId: x.appointmentId, extraId: x.extraId, kind: "extra",
      vetId, vetName: appt.vetName || v.name,
      petName: `Adicionais · ${petLabel(appt, "")}`,
      appointmentDate: appt.date || "",
      ...line, pixKey: v.pixKey, status: "due", createdAt: FV().serverTimestamp(),
    });
    await db().collection("appointments").doc(x.appointmentId).collection("extras").doc(x.extraId)
      .update({ payoutStatus: "due", payoutNet: line.net, payoutFee: line.fee });
    await q.ref.update({ processed: true, payoutId });
    total += line.net;
    lines.push(`${appt.vetName || v.name || "Vet"}: ${brl(line.net)} (adicionais, taxa ${v.pct}%) — PIX: ${v.pixKey}`);
  }
  return { count: lines.length, total: lib.round2(total), held, lines };
}

module.exports = { createCharge, cancelExtra, settleExtraPayment, processExtraPayouts, webhookUrl };
