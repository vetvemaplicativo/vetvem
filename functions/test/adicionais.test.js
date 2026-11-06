// Regras puras dos adicionais (sem Firestore).
const test = require("node:test");
const assert = require("node:assert");
const lib = require("../adicionais_lib");

const H = 3600e3;
const START = Date.parse("2026-11-10T15:00:00-03:00");

test("referência do MP: ida e volta, e não confunde com id de pedido", () => {
  const ref = lib.makeRef("appt123", "ex9");
  assert.equal(ref, "add:appt123:ex9");
  assert.deepEqual(lib.parseRef(ref), { appointmentId: "appt123", extraId: "ex9" });
  assert.equal(lib.parseRef("appt123"), null);
  assert.equal(lib.parseRef("add:so-um"), null);
  assert.equal(lib.parseRef(undefined), null);
});

test("itens: soma no servidor, arredonda e normaliza o nome", () => {
  const r = lib.cleanItems([{ name: "  Curativo   na orelha ", value: 45.5 }, { name: "Vacina", value: "30.005" }]);
  assert.deepEqual(r.items[0], { name: "Curativo na orelha", value: 45.5 });
  assert.equal(r.items[1].value, 30.01);
  assert.equal(r.total, 75.51);
});

test("itens: rejeita vazio, sem nome, valor zero/negativo/NaN e excesso", () => {
  assert.ok(lib.cleanItems([]).error);
  assert.ok(lib.cleanItems(null).error);
  assert.ok(lib.cleanItems([{ name: "", value: 10 }]).error);
  assert.ok(lib.cleanItems([{ name: "x", value: 0 }]).error);
  assert.ok(lib.cleanItems([{ name: "x", value: -5 }]).error);
  assert.ok(lib.cleanItems([{ name: "x", value: "abc" }]).error);
  assert.ok(lib.cleanItems([{ name: "x".repeat(81), value: 10 }]).error);
  assert.ok(lib.cleanItems(Array.from({ length: 21 }, () => ({ name: "x", value: 1 }))).error);
  assert.ok(!lib.cleanItems(Array.from({ length: 20 }, () => ({ name: "x", value: 1 }))).error);
});

test("itens: sem teto de negócio (valor alto passa)", () => {
  assert.equal(lib.cleanItems([{ name: "Cirurgia", value: 12000 }]).total, 12000);
});

test("janela: confirmada abre 30 min antes do horário", () => {
  const appt = { status: "confirmed", paymentStatus: "approved" };
  assert.equal(lib.windowState(appt, START, START - 31 * 60e3).open, false);
  assert.equal(lib.windowState(appt, START, START - 29 * 60e3).open, true);
  assert.equal(lib.windowState(appt, START, START + 3 * H).open, true); // consulta longa ainda aberta
});

test("janela: concluída fecha 2h depois de completedAt", () => {
  const done = START + 1 * H;
  const appt = { status: "completed", paymentStatus: "approved", completedAt: done };
  assert.equal(lib.windowState(appt, START, done + 119 * 60e3).open, true);
  const late = lib.windowState(appt, START, done + 121 * 60e3);
  assert.equal(late.open, false);
  assert.match(late.reason, /2 horas/);
});

test("janela: concluída sem completedAt usa horário + 4h; aceita Timestamp do Firestore", () => {
  const appt = { status: "completed", paymentStatus: "approved" };
  assert.equal(lib.windowState(appt, START, START + 5 * H).open, true);
  assert.equal(lib.windowState(appt, START, START + 7 * H).open, false);
  const ts = { toMillis: () => START + 1 * H };
  assert.equal(lib.windowState({ ...appt, completedAt: ts }, START, START + 3 * H - 60e3).open, true);
});

test("janela: sem pagamento aprovado ou em outro status, fechada", () => {
  assert.equal(lib.windowState({ status: "confirmed", paymentStatus: "pending" }, START, START).open, false);
  for (const status of ["pending_confirmation", "rejected", "cancelled"]) {
    assert.equal(lib.windowState({ status, paymentStatus: "approved" }, START, START).open, false, status);
  }
  assert.equal(lib.windowState({ status: "confirmed", paymentStatus: "approved" }, null, START).open, false);
});

test("repasse: taxa sobre o bruto, D+2 a partir do pagamento", () => {
  assert.deepEqual(lib.payoutLine(100, 15), { gross: 100, fee: 15, net: 85, feePercent: 15 });
  assert.deepEqual(lib.payoutLine(75.51, 12), { gross: 75.51, fee: 9.06, net: 66.45, feePercent: 12 });
  assert.equal(lib.payoutDueAt(START), START + 48 * H);
});
