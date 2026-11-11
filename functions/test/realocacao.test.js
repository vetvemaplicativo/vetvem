const test = require("node:test");
const assert = require("node:assert");
const L = require("../realocacao_lib");

const HOUR = 3600 * 1000;
// 25/10/2026 às 14:00 em Brasília = 17:00 UTC
const apptMs = Date.UTC(2026, 9, 25, 17, 0, 0);

const base = {
  canRelocate: true, paymentStatus: "approved", paymentId: "123",
  addrUf: "RJ", addrCity: "Rio de Janeiro", addrNeighborhood: "Tijuca",
  date: "25/10/2026", time: "14:00", paymentAmount: 150, value: "150,00",
};

test("serviceSimilarity: igual, parecido e diferente", () => {
  assert.equal(L.serviceSimilarity("Consulta", "consulta"), 1);
  assert.equal(L.serviceSimilarity("Consulta", "Consulta domiciliar"), 0.5);
  assert.ok(L.serviceSimilarity("Consulta clínica geral", "Consulta clinica geral") === 1);
  assert.equal(L.serviceSimilarity("Ultrassonografia", "Vacina V10"), 0);
  assert.equal(L.serviceSimilarity("", "Consulta"), 0);
  assert.ok(L.serviceSimilarity("Consulta de rotina", "Consulta rotina em casa") >= 0.5);
});

test("coversAddress: cidade toda, bairro e estado", () => {
  const area = { estado: "RJ", cidades: [
    { nome: "Rio de Janeiro", atende_cidade_toda: false, bairros: ["Tijuca", "Méier"] },
    { nome: "Niterói", atende_cidade_toda: true, bairros: [] },
  ] };
  assert.ok(L.coversAddress(area, "RJ", "Rio de Janeiro", "tijuca"));
  assert.ok(L.coversAddress(area, "rj", "RIO DE JANEIRO", "Meier"));
  assert.ok(!L.coversAddress(area, "RJ", "Rio de Janeiro", "Barra"));
  assert.ok(L.coversAddress(area, "RJ", "Niterói", "Qualquer"));
  assert.ok(L.coversAddress(area, "RJ", "Rio de Janeiro", "")); // sem bairro: basta a cidade
  assert.ok(!L.coversAddress(area, "SP", "Rio de Janeiro", "Tijuca"));
  assert.ok(!L.coversAddress(null, "RJ", "Rio de Janeiro", "Tijuca"));
});

test("worksAt: dia da semana e horário", () => {
  // 25/10/2026 é domingo
  assert.equal(L.weekdayLabel("25/10/2026"), "Dom");
  assert.equal(L.weekdayLabel("26/10/2026"), "Seg");
  assert.ok(L.worksAt({ availableDays: ["Dom"], availableTimes: ["14:00"] }, "25/10/2026", "14:00"));
  assert.ok(!L.worksAt({ availableDays: ["Seg"], availableTimes: ["14:00"] }, "25/10/2026", "14:00"));
  assert.ok(!L.worksAt({ availableDays: ["Dom"], availableTimes: ["09:00"] }, "25/10/2026", "14:00"));
  assert.ok(L.worksAt({}, "25/10/2026", "14:00")); // sem configuração não bloqueia
  assert.ok(L.worksAt({ availableTimes: ["9:00", "14:00"] }, "25/10/2026", "14:00"));
});

test("sharesCategory", () => {
  assert.ok(L.sharesCategory(["Dermatologia"], ["dermatologia", "Clínica Geral"]));
  assert.ok(!L.sharesCategory(["Dermatologia"], ["Ortopedia"]));
  assert.ok(L.sharesCategory([], ["Ortopedia"]));
});

test("pickService: nome parecido, nunca mais caro que o pago", () => {
  const svcs = [
    { name: "Vacina", price: "80" },
    { name: "Consulta domiciliar", price: "140" },
    { name: "Consulta", price: "160" },
  ];
  const pick = L.pickService(svcs, "Consulta", { petCount: 1 }, 150);
  assert.equal(pick.name, "Consulta domiciliar"); // "Consulta" custa 160 > 150
  assert.equal(pick.amount, 140);
  assert.equal(L.pickService(svcs, "Consulta", { petCount: 1 }, 100), null);
  assert.equal(L.pickService(svcs, "Ultrassom", {}, 500), null);
});

test("pickService: total com deslocamento e 2 animais", () => {
  const svc = [{ name: "Consulta", price: "100", travelFee: "30" }];
  assert.equal(L.pickService(svc, "Consulta", { petCount: 2 }, 229), null);
  assert.equal(L.pickService(svc, "Consulta", { petCount: 2 }, 230).amount, 230);
});

test("rankCandidates: mais baratos primeiro, máximo 5", () => {
  const list = [10, 8, 9, 7, 6, 5, 4].map((p, i) => ({ vetId: "v" + i, vetName: "V" + i, price: p, rating: 0 }));
  const out = L.rankCandidates(list);
  assert.equal(out.length, 5);
  assert.deepEqual(out.map((o) => o.price), [4, 5, 6, 7, 8]);
});

test("canRelocate: condições", () => {
  const now = apptMs - 6 * HOUR;
  assert.ok(L.canRelocate(base, now).ok);
  assert.equal(L.canRelocate({ ...base, canRelocate: false }, now).ok, false);
  assert.equal(L.canRelocate({ ...base, bookingOrigin: "portal_web" }, now).ok, false);
  assert.equal(L.canRelocate({ ...base, paymentStatus: "pending" }, now).ok, false);
  assert.equal(L.canRelocate({ ...base, addrUf: "" }, now).ok, false);
  assert.equal(L.canRelocate({ ...base, relocationRound: 2 }, now).ok, false);
  assert.ok(L.canRelocate({ ...base, relocationRound: 1 }, now).ok);
  assert.equal(L.canRelocate(base, apptMs - 4 * HOUR).ok, false); // < 5h
  assert.ok(L.canRelocate(base, apptMs - 5 * HOUR).ok);
});

test("prazos: tutor 1h; profissional min(3h, 1h antes da consulta)", () => {
  const now = apptMs - 6 * HOUR;
  assert.equal(L.tutorDeadline(now), now + 60 * 60 * 1000);
  assert.equal(L.vetDeadline(now, apptMs), now + 3 * HOUR); // 3h < 5h
  const late = apptMs - 90 * 60 * 1000;
  assert.equal(L.vetDeadline(late, apptMs), apptMs - HOUR); // 1h antes da consulta
});

test("paidAmount e moneyString", () => {
  assert.equal(L.paidAmount({ paymentAmount: 150 }), 150);
  assert.equal(L.paidAmount({ value: "99,90" }), 99.9);
  assert.equal(L.moneyString(99.9), "99,90");
  assert.equal(L.moneyString(1000), "1000,00");
});

test("portal: precisa de e-mail e de 6h; prazo da tutora é 2h", () => {
  const now = apptMs - 7 * HOUR;
  const portal = { ...base, bookingOrigin: "portal_web", email: "t@t.com" };
  assert.ok(L.canRelocate(portal, now).ok);
  assert.equal(L.canRelocate({ ...portal, email: "" }, now).ok, false);
  assert.equal(L.canRelocate(portal, apptMs - 5 * HOUR).ok, false); // < 6h
  assert.ok(L.canRelocate(portal, apptMs - 6 * HOUR).ok);
  assert.equal(L.tutorDeadline(now, true), now + 120 * 60 * 1000);
  assert.equal(L.tutorDeadline(now, false), now + 60 * 60 * 1000);
});
