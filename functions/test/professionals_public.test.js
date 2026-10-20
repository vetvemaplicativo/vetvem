// node --test functions/test/professionals_public.test.js
const test = require("node:test");
const assert = require("node:assert");
const { isPublic, buildPublicDoc } = require("../professionals_public").__test;

const PRIVATE_KEYS = ["phone", "email", "address", "pixKeys", "termos_aceitos",
  "termos_aceitos_em", "termos_versao", "fcmToken", "platform", "feeOverride",
  "pixChangedAt", "createdAt", "accountStatus", "blocked", "role"];

const fullUser = () => ({
  role: "professional", accountStatus: "approved",
  name: " Dra. Ana ", email: "ana@x.com", phone: "21999999999", crmv: "RJ-123",
  bio: "Bio", categories: ["Clínica Geral"],
  services: [{ name: "Consulta", price: "150,00", unit: "consulta", segredo: "x" },
    { name: "Vacina", price: "80", unit: "consulta", perAnimal: true, additionalPrice: "60" }],
  availableDays: ["seg"], availableTimes: ["09:00"],
  address: { cep: "24000-000", street: "Rua A", number: "10", complement: "ap 1" },
  pixKeys: [{ type: "cpf", key: "12345678900" }],
  animalSpecies: ["dog"],
  area_atuacao: { estado: "RJ", extra: "z", cidades: [{ nome: "Niterói", ibge_id: "3303302", atende_cidade_toda: true, bairros: ["Icaraí"], lixo: 1 }] },
  area_atuacao_keys: ["RJ|3303302"],
  photoBase64: "AAA", rating: 4.5, reviewCount: 3, completedCount: 7,
  termos_aceitos: true, termos_versao: "1", fcmToken: "tok", platform: "ios",
  createdAt: new Date(), feeOverride: 5, pixChangedAt: new Date(),
});

test("espelho nunca contém campo privado", () => {
  const pub = buildPublicDoc(fullUser());
  for (const k of PRIVATE_KEYS) assert.ok(!(k in pub), `vazou ${k}`);
  const json = JSON.stringify(pub);
  for (const secret of ["21999999999", "ana@x.com", "12345678900", "Rua A", "24000-000", "tok", "segredo", "lixo"]) {
    assert.ok(!json.includes(secret), `vazou valor ${secret}`);
  }
});

test("campos públicos preservados e normalizados", () => {
  const pub = buildPublicDoc(fullUser());
  assert.equal(pub.name, " Dra. Ana "); // idêntico ao users (app casa por vetName)
  assert.deepEqual(pub.services, [
    { name: "Consulta", price: "150,00", unit: "consulta" },
    { name: "Vacina", price: "80", unit: "consulta", perAnimal: true, additionalPrice: "60" },
  ]);
  assert.equal(pub.area_atuacao.cidades[0].ibge_id, "3303302");
  assert.equal(pub.rating, 4.5);
  assert.equal(pub.isAvailable, true);
  assert.equal(buildPublicDoc({ ...fullUser(), isAvailable: false }).isAvailable, false);
});

test("doc mínimo/malformado não quebra", () => {
  const pub = buildPublicDoc({ role: "professional" });
  assert.equal(pub.area_atuacao, null);
  assert.deepEqual(pub.services, []);
  assert.equal(pub.rating, 0);
  assert.doesNotThrow(() => buildPublicDoc({ services: [null, "x", { name: 1 }], categories: "x" }));
});

test("isPublic: aprovado/active e não bloqueado", () => {
  assert.ok(isPublic({ role: "professional", accountStatus: "approved" }));
  assert.ok(isPublic({ role: "professional", accountStatus: "active" }));
  assert.ok(!isPublic({ role: "professional", accountStatus: "pending" }));
  assert.ok(!isPublic({ role: "professional", accountStatus: "approved", blocked: true }));
  assert.ok(!isPublic({ role: "tutor", accountStatus: "approved" }));
  assert.ok(!isPublic(null));
});

test("index.js não expõe __test como função", () => {
  const exported = Object.assign({}, require("../professionals_public"));
  assert.deepEqual(Object.keys(exported).sort(),
    ["mirrorProfessionalPublic", "reconcileProfessionalsPublic", "reconcileProfessionalsPublicNow"]);
});

test("vitrine: serviço leva taxa de deslocamento e orientações (e corta orientação > 240)", () => {
  const longo = "x".repeat(300);
  const pub = buildPublicDoc({ name: "A", services: [
    { name: "US", price: "200", unit: "consulta", travelFee: "80", instructions: "  Jejum de 6 horas  " },
    { name: "Longo", price: "10", unit: "consulta", instructions: longo },
    { name: "Sem", price: "10", unit: "consulta", travelFee: "", instructions: "" },
  ] });
  assert.equal(pub.services[0].travelFee, "80");
  assert.equal(pub.services[0].instructions, "Jejum de 6 horas");
  assert.equal(pub.services[1].instructions.length, 240);
  assert.equal(pub.services[2].travelFee, undefined);
  assert.equal(pub.services[2].instructions, undefined);
});
