const test = require("node:test");
const assert = require("node:assert");
const T = require("../travel_lib");
const { priceForService } = require("../appointment_amount");

const rules = T.mergeRules(null);

test("regras padrão e config inválida", () => {
  assert.deepEqual(rules, { maxPerKm: 3, maxTotal: 80, fallbackFactor: 1.3, maxRadiusKm: 100 });
  const r = T.mergeRules({ maxPerKm: "2,5", maxTotal: -1, fallbackFactor: "abc" });
  assert.equal(r.maxPerKm, 2.5);
  assert.equal(r.maxTotal, 80);
  assert.equal(r.fallbackFactor, 1.3);
});

test("normalizeCep", () => {
  assert.equal(T.normalizeCep("20040-020"), "20040020");
  assert.equal(T.normalizeCep(" 20040020 "), "20040020");
  assert.equal(T.normalizeCep("2004002"), null);
  assert.equal(T.normalizeCep(""), null);
  assert.equal(T.normalizeCep(null), null);
});

test("haversine: Rio -> Niterói ~ 10 km", () => {
  const d = T.haversineKm({ lat: -22.9035, lng: -43.1729 }, { lat: -22.8833, lng: -43.1036 });
  assert.ok(d > 6 && d < 9, String(d));
  assert.equal(T.haversineKm({ lat: 1, lng: 1 }, { lat: 1, lng: 1 }), 0);
});

test("vetTravelConfig: só 'per_km' com valor; aplica teto por km e raio", () => {
  assert.equal(T.vetTravelConfig({}, rules), null);
  assert.equal(T.vetTravelConfig({ travelModel: "fixed" }, rules), null);
  assert.equal(T.vetTravelConfig({ travelModel: "per_km" }, rules), null);
  assert.equal(T.vetTravelConfig({ travelModel: "per_km", travelPerKm: "0" }, rules), null);
  const c = T.vetTravelConfig({ travelModel: "per_km", travelPerKm: "5,50", travelRoundTrip: true, travelMaxKm: "500" }, rules);
  assert.deepEqual(c, { perKm: 3, roundTrip: true, maxKm: 100 }); // 5,50 -> teto 3; 500 km -> teto 100
  const d = T.vetTravelConfig({ travelModel: "per_km", travelPerKm: 2 }, rules);
  assert.deepEqual(d, { perKm: 2, roundTrip: false, maxKm: 100 });
});

test("feeForDistance: só ida e ida e volta", () => {
  const ida = T.feeForDistance(10, { perKm: 2, roundTrip: false, maxKm: 30 }, rules);
  assert.equal(ida.fee, 20);
  assert.equal(ida.billedKm, 10);
  const idaVolta = T.feeForDistance(10, { perKm: 2, roundTrip: true, maxKm: 30 }, rules);
  assert.equal(idaVolta.fee, 40);
  assert.equal(idaVolta.billedKm, 20);
  assert.equal(idaVolta.capped, false);
});

test("feeForDistance: teto total de R$ 80 e raio máximo", () => {
  const cap = T.feeForDistance(40, { perKm: 3, roundTrip: true, maxKm: 100 }, rules); // 240 -> 80
  assert.equal(cap.fee, 80);
  assert.equal(cap.capped, true);
  const out = T.feeForDistance(31, { perKm: 2, roundTrip: false, maxKm: 30 }, rules);
  assert.equal(out.outOfRange, true);
  assert.equal(out.fee, 0);
  assert.equal(T.feeForDistance(30, { perKm: 2, roundTrip: false, maxKm: 30 }, rules).outOfRange, false);
});

test("feeForDistance: arredonda km a 0,1 e valor a centavos", () => {
  const r = T.feeForDistance(7.349, { perKm: 2.5, roundTrip: false, maxKm: 30 }, rules);
  assert.equal(r.km, 7.3);
  assert.equal(r.fee, 18.25); // 7,3 × 2,5
});

test("preço: deslocamento por km substitui a taxa fixa e respeita feesDisclosed", () => {
  const svc = { price: "100", travelFee: "30" };
  assert.equal(priceForService(svc, { feesDisclosed: true }, { travelFee: 45 }).amount, 145);
  assert.equal(priceForService(svc, { feesDisclosed: true }, { travelFee: 0 }).amount, 100); // por km = 0, ignora os R$ 30 fixos
  assert.equal(priceForService(svc, { feesDisclosed: true }).amount, 130); // sem opts: taxa fixa como sempre
  assert.equal(priceForService(svc, {}, { travelFee: 45 }).amount, 100); // cliente que não mostrou a taxa
  assert.equal(priceForService(svc, { feesDisclosed: true, petCount: 2 }, { travelFee: 45 }).amount, 245); // uma vez por visita
});
