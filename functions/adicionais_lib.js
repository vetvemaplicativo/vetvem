// Adicionais durante o atendimento — regras puras (sem Firestore).
// O profissional lança procedimentos extras (curativo, medicação, vacina...) durante ou depois da
// consulta e gera UM QR PIX com o total. O tutor autoriza na conversa, não no app.
// Doc: appointments/{id}/extras/{extraId}  status: draft → awaiting_payment → paid | cancelled | expired

const HOUR = 60 * 60 * 1000;
const MIN = 60 * 1000;

const MAX_ITEMS = 20;
const NAME_MAX = 80;
const VALUE_MAX = 9999999;        // só proteção técnica (sem teto de negócio)
const WINDOW_BEFORE_MIN = 30;     // libera 30 min antes do horário da consulta
const WINDOW_AFTER_HOURS = 2;     // até 2h depois de concluída
const PIX_MINUTES = 30;
const PAYOUT_DELAY_DAYS = 2;      // D+2 a partir do PAGAMENTO do adicional

const REF_PREFIX = "add";

// external_reference do Mercado Pago: separa o pagamento do adicional do pagamento do pedido.
function makeRef(appointmentId, extraId) {
  return `${REF_PREFIX}:${appointmentId}:${extraId}`;
}
function parseRef(ref) {
  const m = /^add:([^:]+):([^:]+)$/.exec(String(ref || ""));
  return m ? { appointmentId: m[1], extraId: m[2] } : null;
}

const round2 = (n) => Math.round(n * 100) / 100;

// Valida e normaliza os itens do rascunho. O total é SEMPRE recalculado aqui (nunca vem do app).
function cleanItems(items) {
  if (!Array.isArray(items) || items.length === 0) return { error: "Adicione ao menos um item." };
  if (items.length > MAX_ITEMS) return { error: `No máximo ${MAX_ITEMS} itens por cobrança.` };
  const out = [];
  for (const it of items) {
    const name = String((it && it.name) || "").trim().replace(/\s+/g, " ");
    const value = Number(it && it.value);
    if (!name) return { error: "Todo item precisa de um nome." };
    if (name.length > NAME_MAX) return { error: `Nome do item muito longo (máx. ${NAME_MAX}).` };
    if (!Number.isFinite(value) || value <= 0) return { error: `Valor inválido em "${name}".` };
    if (value > VALUE_MAX) return { error: `Valor inválido em "${name}".` };
    out.push({ name, value: round2(value) });
  }
  const total = round2(out.reduce((s, i) => s + i.value, 0));
  if (total <= 0) return { error: "O total precisa ser maior que zero." };
  return { items: out, total };
}

function toMs(v) {
  if (v == null) return null;
  if (typeof v === "number") return v;
  if (typeof v.toMillis === "function") return v.toMillis();
  if (typeof v.toDate === "function") return v.toDate().getTime();
  if (typeof v._seconds === "number") return v._seconds * 1000;
  if (typeof v.seconds === "number") return v.seconds * 1000;
  if (typeof v.__ts === "number") return v.__ts;
  return null;
}

// Pode lançar/cobrar adicionais agora?
//  - consulta confirmada: a partir de 30 min antes do horário;
//  - consulta concluída: até 2h depois de concluída;
//  - qualquer outro status: não. Depois da janela, só o suporte.
// startMs: horário da consulta (ms) — null se a data do pedido for inválida.
function windowState(appt, startMs, nowMs) {
  const a = appt || {};
  if (a.paymentStatus !== "approved") return { open: false, reason: "A consulta ainda não foi paga." };
  if (a.status === "confirmed") {
    if (startMs == null) return { open: false, reason: "Data da consulta inválida." };
    if (nowMs < startMs - WINDOW_BEFORE_MIN * MIN) {
      return { open: false, reason: "Os adicionais abrem 30 minutos antes da consulta." };
    }
    return { open: true };
  }
  if (a.status === "completed") {
    const done = toMs(a.completedAt) ?? (startMs != null ? startMs + 4 * HOUR : null);
    if (done == null) return { open: false, reason: "Não foi possível confirmar quando a consulta terminou." };
    if (nowMs > done + WINDOW_AFTER_HOURS * HOUR) {
      return { open: false, reason: "O prazo de 2 horas para lançar adicionais acabou. Fale com o suporte." };
    }
    return { open: true };
  }
  return { open: false, reason: "Adicionais só podem ser lançados em consulta confirmada ou recém-concluída." };
}

// Valores do repasse de um adicional pago.
function payoutLine(gross, feePercent) {
  const fee = round2((gross * feePercent) / 100);
  return { gross: round2(gross), fee, net: round2(gross - fee), feePercent };
}

const payoutDueAt = (paidAtMs) => paidAtMs + PAYOUT_DELAY_DAYS * 24 * HOUR;

module.exports = {
  MAX_ITEMS, NAME_MAX, WINDOW_BEFORE_MIN, WINDOW_AFTER_HOURS, PIX_MINUTES, PAYOUT_DELAY_DAYS,
  makeRef, parseRef, cleanItems, windowState, payoutLine, payoutDueAt, toMs, round2,
};
