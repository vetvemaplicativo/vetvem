// node --test functions/test/appointment_amount.test.js
const test = require("node:test");
const assert = require("node:assert");
const { priceForService, animalsOf } = require("../appointment_amount");

const comum = (price) => ({ name: "Vacina", price, unit: "consulta" });
const porAnimal = (price, additionalPrice) => ({ name: "Vacina", price, unit: "consulta", perAnimal: true, additionalPrice });

test("1 animal: valor do serviço, qualquer tipo (compatível com apps antigos)", () => {
  assert.deepEqual(priceForService(comum("100"), {}), { amount: 100, count: 1 });
  assert.deepEqual(priceForService(comum("100"), { petCount: 1 }), { amount: 100, count: 1 });
  assert.deepEqual(priceForService(porAnimal("100", "60"), { petCount: 1 }), { amount: 100, count: 1 });
});

test("serviço comum com vários animais: preço cheio × n, sem desconto (caso do pedido: 2 × R$100 = R$200)", () => {
  assert.deepEqual(priceForService(comum("100"), { petCount: 2 }), { amount: 200, count: 2 });
  assert.deepEqual(priceForService(comum("80,50"), { petCount: 3, pets: [{}, {}, {}] }), { amount: 241.5, count: 3 });
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
