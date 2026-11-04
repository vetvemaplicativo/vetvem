// Duas contas do Mercado Pago convivendo (transição para a conta do CNPJ).
//  - "v1": conta antiga (segredo MP_ACCESS_TOKEN). Apps antigos geram o token do cartão com a
//    Public Key dela.
//  - "v2": conta nova (segredo MP_ACCESS_TOKEN_V2). O tutor 1.0.18+ usa a Public Key dela.
// O token de cartão (e o customer/cartão salvo) só vale na conta que o criou; por isso o servidor
// tenta uma conta e, se o MP responder "não encontrado", tenta a outra (a primeira tentativa não
// cobra nada). Cada pedido guarda em qual conta foi pago (paymentAccount) para estorno, consulta
// e webhook usarem o token certo.
const { defineSecret } = require("firebase-functions/params");

const MP_SECRET = defineSecret("MP_ACCESS_TOKEN");
const MP_SECRET_V2 = defineSecret("MP_ACCESS_TOKEN_V2");

// Ordem de tentativa. Cartão: apps antigos (v1) acertam de primeira; o app novo cai em v2.
// PIX é só servidor: fica em v1 até testarmos a conta nova; depois vira ["v2", "v1"].
const CARD_ORDER = ["v1", "v2"];
const PIX_ORDER = ["v1"];

function tokenOf(account) {
  const raw = account === "v2" ? MP_SECRET_V2.value() : MP_SECRET.value();
  return String(raw || "").trim();
}

// Conta em que o pedido foi pago (pedidos antigos não têm o campo: são da v1).
function accountOf(appt) {
  return appt && appt.paymentAccount === "v2" ? "v2" : "v1";
}

// O MP respondeu que o token do cartão / customer não existe NESTA conta?
function isWrongAccountError(err) {
  const r = err && err.response;
  if (!r || (r.status !== 400 && r.status !== 404)) return false;
  const d = r.data || {};
  const causes = Array.isArray(d.cause) ? d.cause : [];
  // 17 = "Invalid credentials": token de cartão gerado com a Public Key de OUTRA conta (visto em produção).
  if (causes.some((c) => c && [17, 2006, 2002].includes(Number(c.code)))) return true;
  const msg = `${d.message || ""} ${causes.map((c) => (c && c.description) || "").join(" ")}`;
  if (/invalid credentials/i.test(msg)) return true;
  return /(card[ _]?token|token|customer|card).{0,30}not found|not found.{0,30}(card[ _]?token|token|customer|card)/i.test(msg);
}

// Roda fn(account) na ordem dada. Se falhar por "conta errada", passa para a próxima.
// Retorna { account, value }. Se todas falharem, devolve o erro que NÃO é de conta errada
// (o motivo real), ou o primeiro. shouldRetry pode ser trocado (ex.: PIX tenta a outra em
// qualquer erro).
async function withAccountFallback(order, fn, shouldRetry = isWrongAccountError) {
  let firstErr = null;
  for (let i = 0; i < order.length; i++) {
    try {
      return { account: order[i], value: await fn(order[i]) };
    } catch (e) {
      if (!firstErr) firstErr = e;
      const last = i === order.length - 1;
      if (!shouldRetry(e) || last) throw shouldRetry(e) ? firstErr : e;
    }
  }
  throw firstErr || new Error("sem conta do Mercado Pago");
}

module.exports = {
  MP_SECRET,
  MP_SECRET_V2,
  CARD_ORDER,
  PIX_ORDER,
  tokenOf,
  accountOf,
  isWrongAccountError,
  withAccountFallback,
};
