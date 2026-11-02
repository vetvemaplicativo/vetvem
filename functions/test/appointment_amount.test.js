// node --test functions/test/appointment_amount.test.js
const test = require("node:test");
const assert = require("node:assert");
const { priceForService, animalsOf } = require("../appointment_amount");

const comum = (price) => ({ name: "Vacina", price, unit: "consulta" });
const porAnimal = (price, additionalPrice) => ({ name: "Vacina", price, unit: "consulta", perAnimal: true, additionalPrice });

test("1 animal: valor do serviço, qualquer tipo (compatível com apps antigos)", () => {
  assert.deepEqual(priceForService(comum("100"), {}), { amount: 100, count: 1, travel: 0 });
  assert.deepEqual(priceForService(comum("100"), { petCount: 1 }), { amount: 100, count: 1, travel: 0 });
  assert.deepEqual(priceForService(porAnimal("100", "60"), { petCount: 1 }), { amount: 100, count: 1, travel: 0 });
});

test("serviço comum com vários animais: preço cheio × n, sem desconto (caso do pedido: 2 × R$100 = R$200)", () => {
  assert.deepEqual(priceForService(comum("100"), { petCount: 2 }), { amount: 200, count: 2, travel: 0 });
  assert.deepEqual(priceForService(comum("80,50"), { petCount: 3, pets: [{}, {}, {}] }), { amount: 241.5, count: 3, travel: 0 });
  // additionalPrice só vale em serviço "por animal"
  assert.equal(priceForService({ ...comum("100"), additionalPrice: "10" }, { petCount: 2 }).amount, 200);
});

test("serviço por animal: usa o adicional configurado, ou o preço cheio se não houver", () => {
  assert.equal(priceForService(porAnimal("80", "60"), { petCount: 3 }).amount, 200);
  assert.equal(priceForService(porAnimal("80", undefined), { petCount: 3 }).amount, 240);
  assert.equal(priceForService(porAnimal("80", ""), { petCount: 2 }).amount, 160);
});

test("conta de animais: maior entre petCount e pets[], mínimo 1, teto 50", () => {
  assert.equal(animalsOf({}), 1);
  assert.equal(animalsOf({ petCount: "4" }), 4);
  assert.equal(animalsOf({ petCount: 2, pets: [{}, {}, {}] }), 3);
  assert.equal(animalsOf({ petCount: 999 }), 50);
  assert.equal(animalsOf({ petCount: -3 }), 1);
});

test("preço inválido: null (o servidor mantém o valor do app)", () => {
  assert.equal(priceForService(comum("0"), { petCount: 2 }), null);
  assert.equal(priceForService({ name: "x" }, { petCount: 2 }), null);
});

test("arredondamento em centavos", () => {
  assert.equal(priceForService(comum("33.33"), { petCount: 3 }).amount, 99.99);
  assert.equal(priceForService(porAnimal("10", "0.333"), { petCount: 4 }).amount, 11);
});

test("petLabel: nome do pet com +N quando há vários animais", () => {
  const { petLabel } = require("../appointment_amount");
  assert.equal(petLabel({ petName: "Mingau" }, "seu pet"), "Mingau");
  assert.equal(petLabel({ petName: "Mingau", petCount: 13 }, "seu pet"), "Mingau +12");
  assert.equal(petLabel({ petName: "Mingau", pets: [1, 2, 3] }, "seu pet"), "Mingau +2");
  assert.equal(petLabel({}, "seu pet"), "seu pet");
  assert.equal(petLabel({ petCount: 4 }, "seu pet"), "4 animais");
});

test("taxa de deslocamento: fixa por visita, soma uma vez só, independe do nº de animais", () => {
  // serviço comum: 200 + deslocamento 80 = 280
  assert.equal(priceForService({ price: "200", travelFee: "80" }, { feesDisclosed: true }).amount, 280);
  // 13 gatos, serviço comum (preço cheio x n) + 1x deslocamento
  assert.equal(priceForService({ price: "80", travelFee: 80 }, { petCount: 13, feesDisclosed: true }).amount, 80 * 13 + 80);
  // por animal com adicional: 80 + 2x60 + 50
  assert.equal(priceForService({ price: "80", perAnimal: true, additionalPrice: "60", travelFee: "50" }, { petCount: 3, feesDisclosed: true }).amount, 80 + 120 + 50);
  // sem taxa / taxa inválida ou zero não altera o valor
  assert.equal(priceForService({ price: "200" }, {}).amount, 200);
  assert.equal(priceForService({ price: "200", travelFee: "abc" }, { feesDisclosed: true }).amount, 200);
  assert.equal(priceForService({ price: "200", travelFee: 0 }, { feesDisclosed: true }).amount, 200);
});

test("taxa de deslocamento NAO é cobrada de cliente antigo (sem feesDisclosed)", () => {
  assert.equal(priceForService({ price: "200", travelFee: "80" }, {}).amount, 200);
  assert.equal(priceForService({ price: "200", travelFee: "80" }, { feesDisclosed: false }).amount, 200);
  assert.equal(priceForService({ price: "200", travelFee: "80" }, { petCount: 2 }).amount, 400);
});

// ── Vários serviços na mesma consulta ──
const { priceForServices, serviceNamesOf } = require("../appointment_amount");
const cons = { name: "Consulta", price: "150", unit: "consulta" };
const vac = { name: "Vacina", price: "80", unit: "consulta", perAnimal: true, additionalPrice: "60" };

test("serviceNamesOf: lista com 2+ nomes; senão serviceName; sem repetidos", () => {
  assert.deepEqual(serviceNamesOf({ serviceName: "A" }), ["A"]);
  assert.deepEqual(serviceNamesOf({ serviceName: "A + B", services: [{ name: "A" }, { name: "B" }] }), ["A", "B"]);
  assert.deepEqual(serviceNamesOf({ serviceName: "A", services: [{ name: "A" }, { name: "A" }] }), ["A"]);
  assert.deepEqual(serviceNamesOf({}), []);
  const many = Array.from({ length: 30 }, (_, i) => ({ name: "S" + i }));
  assert.equal(serviceNamesOf({ services: many }).length, 10);
});

test("vários serviços: soma dos preços, 1 animal", () => {
  assert.deepEqual(priceForServices([cons, vac], {}, undefined), { amount: 230, count: 1, travel: 0 });
});

test("vários serviços com vários animais: cada serviço segue a própria regra", () => {
  // consulta (comum) 2 × 150 + vacina (por animal) 80 + 60
  assert.equal(priceForServices([cons, vac], { petCount: 2 }, undefined).amount, 440);
});

test("deslocamento fixo: cobra uma vez (a maior taxa), só se divulgada", () => {
  const a = { ...cons, travelFee: "20" };
  const b = { ...vac, travelFee: "30" };
  assert.equal(priceForServices([a, b], { feesDisclosed: true }, undefined).amount, 260);
  assert.equal(priceForServices([a, b], {}, undefined).amount, 230);
});

test("deslocamento por km: valor calculado uma vez só", () => {
  const r = priceForServices([cons, vac], { feesDisclosed: true }, { travelFee: 47.4 });
  assert.deepEqual(r, { amount: 277.4, count: 1, travel: 47.4 });
  assert.equal(priceForServices([cons, vac], { feesDisclosed: true }, { travelFee: 0 }).amount, 230);
});

test("serviço sem preço válido invalida o conjunto", () => {
  assert.equal(priceForServices([cons, { name: "x" }], {}, undefined), null);
});
