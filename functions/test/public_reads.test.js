const test = require("node:test");
const assert = require("node:assert");
const L = require("../public_reads_lib");

test("busyTimes: só o dia pedido, só confirmed/pending, sem repetir, ordenado", () => {
  const docs = [
    { date: "11/11/2026", time: "10:00", status: "confirmed" },
    { date: "11/11/2026", time: "09:00", status: "pending_confirmation" },
    { date: "11/11/2026", time: "09:00", status: "confirmed" },
    { date: "11/11/2026", time: "11:00", status: "cancelled" },
    { date: "11/11/2026", time: "12:00", status: "rejected" },
    { date: "12/11/2026", time: "08:00", status: "confirmed" },
    { date: "11/11/2026", time: "", status: "confirmed" },
  ];
  assert.deepEqual(L.pickBusyTimes(docs, "11/11/2026"), ["09:00", "10:00"]);
  assert.deepEqual(L.pickBusyTimes(docs, "13/11/2026"), []);
});

test("busyTimes: não devolve nada além dos horários", () => {
  const out = L.pickBusyTimes([{ date: "11/11/2026", time: "09:00", status: "confirmed", tutorName: "Maria", address: "Rua X" }], "11/11/2026");
  assert.deepEqual(out, ["09:00"]);
});

test("vetReviews: só avaliados, primeiro nome, ordem do mais novo, média com 1 casa", () => {
  const r = L.pickReviews([
    { rating: 5, comment: "ótima", tutorName: "Maria Silva", petName: "Rex", date: "05/11/2026", email: "x@x.com", address: "Rua" },
    { rating: 4, tutorName: "João", petName: "Mel", date: "20/10/2026" },
    { rating: 0, tutorName: "Zé", date: "01/11/2026" },
    { tutorName: "Ana", date: "02/11/2026" },
    { rating: 5, tutorName: "  ", date: "10/11/2026" },
  ]);
  assert.equal(r.reviewCount, 3);
  assert.equal(r.rating, 4.7);
  assert.deepEqual(r.reviews.map((x) => x.date), ["10/11/2026", "05/11/2026", "20/10/2026"]);
  assert.equal(r.reviews[1].tutorName, "Maria");
  assert.equal(r.reviews[0].tutorName, "Anônimo");
  assert.ok(!("email" in r.reviews[1]) && !("address" in r.reviews[1]));
});

test("vetReviews: vazio", () => {
  assert.deepEqual(L.pickReviews([]), { reviews: [], rating: 0, reviewCount: 0 });
});

test("validDate", () => {
  assert.ok(L.validDate("01/02/2026"));
  assert.ok(!L.validDate("2026-02-01"));
  assert.ok(!L.validDate(""));
});

test("aggregateVet: média, avaliações e concluídos", () => {
  const a = L.aggregateVet([
    { status: "completed", rating: 5 }, { status: "completed", rating: 4 }, { status: "completed" },
    { status: "confirmed", rating: 0 }, { status: "cancelled" },
  ]);
  assert.deepEqual(a, { rating: 4.5, reviewCount: 2, completedCount: 3 });
  assert.deepEqual(L.aggregateVet([]), { rating: 0, reviewCount: 0, completedCount: 0 });
});
