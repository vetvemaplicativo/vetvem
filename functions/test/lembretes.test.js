const test = require("node:test");
const assert = require("node:assert/strict");
const L = require("../lembretes_lib");

const appt = (over = {}) => ({
  status: "confirmed", paymentStatus: "approved", date: "30/10/2026", time: "10:00",
  tutorName: "Silvio Andorinha", vetName: "Matheus", address: "Rua A, 10", petName: "Rex", ...over,
});
// horário de Brasília -> Date
const at = (s) => new Date(`${s}:00-03:00`);

test("só consulta confirmada e paga recebe lembrete", () => {
  const now = at("2026-10-29T18:30");
  assert.deepEqual(L.remindersDue(appt({ status: "pending_confirmation" }), now), []);
  assert.deepEqual(L.remindersDue(appt({ paymentStatus: "pending_payment" }), now), []);
  assert.deepEqual(L.remindersDue(appt({ status: "cancelled" }), now), []);
});

test("véspera: a partir das 18h do dia anterior, profissional e tutor", () => {
  assert.deepEqual(L.remindersDue(appt(), at("2026-10-29T17:59")), []);
  assert.deepEqual(L.remindersDue(appt(), at("2026-10-29T18:00")).sort(), ["tutor_1d", "vet_1d"]);
  assert.deepEqual(L.remindersDue(appt(), at("2026-10-29T20:45")).sort(), ["tutor_1d", "vet_1d"]);
});

test("véspera não sai de madrugada, e sai pela manhã se ainda faltar 3h ou mais", () => {
  assert.deepEqual(L.remindersDue(appt(), at("2026-10-29T23:00")), []);
  assert.deepEqual(L.remindersDue(appt(), at("2026-10-30T03:00")), []);
  assert.deepEqual(L.remindersDue(appt(), at("2026-10-30T07:00")).sort(), ["tutor_1d", "vet_1d"]);
  assert.deepEqual(L.remindersDue(appt({ time: "08:00" }), at("2026-10-30T07:00")), ["vet_2h", "tutor_1h"]);
});

test("não envia o que já foi enviado", () => {
  const sent = { vet_1d: 1, tutor_1d: 1 };
  assert.deepEqual(L.remindersDue(appt({ remindersSent: sent }), at("2026-10-29T19:00")), []);
  assert.deepEqual(L.remindersDue(appt({ remindersSent: { vet_1d: 1 } }), at("2026-10-29T19:00")), ["tutor_1d"]);
});

test("2h antes (profissional) e 1h antes (tutor)", () => {
  const sentDay = { vet_1d: 1, tutor_1d: 1 };
  assert.deepEqual(L.remindersDue(appt({ remindersSent: sentDay }), at("2026-10-30T08:30")), ["vet_2h"]);
  assert.deepEqual(L.remindersDue(appt({ remindersSent: sentDay }), at("2026-10-30T09:10")).sort(), ["tutor_1h", "vet_2h"]);
  assert.deepEqual(
    L.remindersDue(appt({ remindersSent: { ...sentDay, vet_2h: 1 } }), at("2026-10-30T09:10")), ["tutor_1h"]);
});

test("não avisa faltando menos de 15 min nem depois de começar", () => {
  const sentDay = { vet_1d: 1, tutor_1d: 1 };
  assert.deepEqual(L.remindersDue(appt({ remindersSent: sentDay }), at("2026-10-30T09:50")), []);
  assert.deepEqual(L.remindersDue(appt({ remindersSent: sentDay }), at("2026-10-30T10:05")), []);
});

test("consulta marcada em cima da hora só recebe o aviso curto", () => {
  const now = at("2026-10-30T08:30"); // faltam 1h30, sem aviso da véspera
  assert.deepEqual(L.remindersDue(appt(), now), ["vet_2h"]);
});

test("data inválida não quebra", () => {
  assert.deepEqual(L.remindersDue(appt({ date: "" }), new Date()), []);
});

test("textos: profissional, tutor com orientações e plural de animais", () => {
  const v = L.buildMessage("vet_2h", appt(), "Rex +1");
  assert.match(v.body, /10:00/);
  assert.match(v.body, /Rex \+1/);
  assert.match(v.body, /Silvio/);
  assert.match(v.body, /Rua A, 10/);
  assert.ok(!v.body.includes("Andorinha")); // só o primeiro nome do tutor
  const t = L.buildMessage("tutor_1d", appt({ instructionsText: "Jejum de 8h" }), "Rex");
  assert.match(t.body, /amanhã, às 10:00/);
  assert.match(t.body, /Jejum de 8h/);
  const t2 = L.buildMessage("tutor_1d", appt(), "Rex");
  assert.ok(!t2.body.includes("Lembrete do veterinário"));
});
