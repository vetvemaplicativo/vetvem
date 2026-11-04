// node --test functions/test/mp_accounts.test.js
const test = require("node:test");
const assert = require("node:assert");
const { isWrongAccountError, withAccountFallback, accountOf } = require("../mp_accounts");

const mpErr = (status, data) => Object.assign(new Error("mp"), { response: { status, data } });
const wrong = () => mpErr(400, { message: "Card token service not found", cause: [{ code: 2006, description: "Card Token not found" }] });
const real = () => mpErr(400, { message: "Invalid transaction_amount", cause: [{ code: 4021, description: "invalid amount" }] });

test("isWrongAccountError: token/customer inexistente na conta", () => {
  assert.equal(isWrongAccountError(wrong()), true);
  assert.equal(isWrongAccountError(mpErr(404, { message: "Customer not found" })), true);
  assert.equal(isWrongAccountError(mpErr(400, { message: "x", cause: [{ code: 2002 }] })), true);
});

test("isWrongAccountError: Invalid credentials (código 17) = token de outra conta", () => {
  const e = mpErr(400, { message: "Invalid credentials", error: "bad_request", status: 400, cause: [{ code: 17, description: "Invalid credentials" }] });
  assert.equal(isWrongAccountError(e), true);
  assert.equal(isWrongAccountError(mpErr(400, { message: "Invalid credentials" })), true);
});

test("isWrongAccountError: outros erros não contam", () => {
  assert.equal(isWrongAccountError(real()), false);
  assert.equal(isWrongAccountError(mpErr(500, { message: "token not found" })), false);
  assert.equal(isWrongAccountError(new Error("rede")), false);
  assert.equal(isWrongAccountError(null), false);
});

test("accountOf: pedidos antigos são da v1", () => {
  assert.equal(accountOf({}), "v1");
  assert.equal(accountOf(null), "v1");
  assert.equal(accountOf({ paymentAccount: "v2" }), "v2");
});

test("fallback: acerta de primeira, não chama a outra conta", async () => {
  const calls = [];
  const r = await withAccountFallback(["v1", "v2"], async (a) => { calls.push(a); return "ok-" + a; });
  assert.deepEqual(r, { account: "v1", value: "ok-v1" });
  assert.deepEqual(calls, ["v1"]);
});

test("fallback: token de outra conta cai na seguinte (app novo → v2)", async () => {
  const calls = [];
  const r = await withAccountFallback(["v1", "v2"], async (a) => {
    calls.push(a);
    if (a === "v1") throw wrong();
    return "ok";
  });
  assert.deepEqual(r, { account: "v2", value: "ok" });
  assert.deepEqual(calls, ["v1", "v2"]);
});

test("fallback: erro real não tenta a outra conta", async () => {
  const calls = [];
  await assert.rejects(
    withAccountFallback(["v1", "v2"], async (a) => { calls.push(a); throw real(); }),
    (e) => e.response.data.cause[0].code === 4021
  );
  assert.deepEqual(calls, ["v1"]);
});

test("fallback: erro real da 2ª conta prevalece sobre 'conta errada' da 1ª", async () => {
  await assert.rejects(
    withAccountFallback(["v1", "v2"], async (a) => { throw a === "v1" ? wrong() : real(); }),
    (e) => e.response.data.cause[0].code === 4021
  );
});

test("fallback: as duas contas erradas devolvem o primeiro erro", async () => {
  const first = wrong();
  let n = 0;
  await assert.rejects(
    withAccountFallback(["v1", "v2"], async () => { throw n++ === 0 ? first : wrong(); }),
    (e) => e === first
  );
});

test("fallback com shouldRetry sempre (PIX): qualquer erro tenta a próxima", async () => {
  const r = await withAccountFallback(["v2", "v1"], async (a) => {
    if (a === "v2") throw mpErr(500, {});
    return "pix";
  }, () => true);
  assert.deepEqual(r, { account: "v1", value: "pix" });
});

test("lista com uma conta só: erro sobe como antes", async () => {
  await assert.rejects(withAccountFallback(["v1"], async () => { throw wrong(); }));
});
