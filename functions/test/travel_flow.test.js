// Cálculo de deslocamento contra Firestore e mapa falsos (sem rede).
const test = require("node:test");
const assert = require("node:assert");
const Module = require("node:module");
const { EventEmitter } = require("node:events");

const store = new Map();
const clone = (o) => JSON.parse(JSON.stringify(o));
function docRef(path) {
  return {
    id: path.split("/").pop(), path,
    async get() { const has = store.has(path); return { exists: has, data: () => (has ? clone(store.get(path)) : undefined) }; },
    async set(d) { store.set(path, clone(d)); },
    async update(p) { store.set(path, { ...(store.get(path) || {}), ...clone(p) }); },
    async delete() { store.delete(path); },
  };
}
const fakeAdmin = {
  initializeApp() {},
  firestore: Object.assign(() => ({
    collection: (n) => ({
      doc: (id) => docRef(`${n}/${id}`),
      where() { const q = { where: () => q, async get() { return { docs: [] }; } }; return q; },
      async get() {
        return { docs: [...store.entries()].filter(([p]) => p.startsWith(n + "/") && !p.slice(n.length + 1).includes("/"))
          .map(([p, d]) => ({ id: p.split("/").pop(), data: () => clone(d) })) };
      },
    }),
  }), { FieldValue: { serverTimestamp: () => ({}), delete: () => ({ __delete: true }) } }),
  auth: () => ({ verifyIdToken: async (t) => { if (t === "bad") throw new Error("x"); return { uid: t }; } }),
};

const calls = [];
let brasilCoords = {};          // cep -> {latitude, longitude}
let awesomeCoords = {};         // cep -> {lat, lng}
let routeMeters = 12000;        // null => serviço de rotas fora do ar
const fakeAxios = {
  async get(url, opts) {
    calls.push({ m: "GET", url });
    if (url.includes("awesomeapi")) {
      const c = awesomeCoords[url.split("/").pop()];
      if (!c) throw new Error("404");
      return { data: c };
    }
    if (url.includes("brasilapi")) {
      const cep = url.split("/").pop();
      const c = brasilCoords[cep];
      return { data: { location: { coordinates: c || {} } } };
    }
    if (url.includes("viacep")) return { data: { localidade: "Rio de Janeiro", uf: "RJ", bairro: "Centro", logradouro: "Rua A" } };
    if (url.includes("/geocode/search")) return { data: { features: [{ geometry: { coordinates: [-43.17, -22.9] } }] } };
    throw new Error("url inesperada " + url);
  },
  async post(url, body) {
    calls.push({ m: "POST", url, body });
    if (url.includes("directions")) {
      if (routeMeters === null) throw new Error("ors fora do ar");
      return { data: { routes: [{ summary: { distance: routeMeters } }] } };
    }
    return { data: {} };
  },
};
const origLoad = Module._load;
Module._load = function (request, ...rest) {
  if (request === "firebase-admin") return fakeAdmin;
  if (request === "axios") return fakeAxios;
  return origLoad.call(this, request, ...rest);
};
const core = require("../travel_core");
const { travelQuote } = require("../travel");
const rcore = require("../realocacao_core");
Module._load = origLoad;

function post(fn, uid, body) {
  return new Promise((resolve) => {
    const req = { method: "POST", headers: { authorization: `Bearer ${uid}` }, body, get() {} };
    const res = new EventEmitter();
    Object.assign(res, {
      statusCode: 200,
      status(c) { this.statusCode = c; return this; },
      json(b) { resolve({ code: this.statusCode, body: b }); return this; },
      headersSent: false,
      send(b) { resolve({ code: this.statusCode, body: b }); return this; },
      set() { return this; }, setHeader() { return this; }, getHeader() {}, end() {}, writeHead() { return this; }, write() {},
    });
    fn(req, res);
  });
}

const KEY = "ors-key";
function seed(vetOver = {}) {
  store.clear(); calls.length = 0; routeMeters = 12000;
  awesomeCoords = { "22000000": { lat: "-22.95", lng: "-43.20" } }; // destino com coordenadas
  brasilCoords = {};
  store.set("users/vet1", { role: "professional", travelModel: "per_km", travelPerKm: "2", travelRoundTrip: false, travelMaxKm: "30", ...vetOver });
  store.set("vet_origins/vet1", { lat: -22.9, lng: -43.17, cep: "20040020", v: 3, at: 1 });
}
const roadCalls = () => calls.filter((c) => c.url.includes("directions"));

test("quote: por estrada, só ida; guarda no cache e não repete a consulta", async () => {
  seed();
  const q = await core.quoteTravel("vet1", "22000-000", { orsKey: KEY, uid: "t1" });
  assert.equal(q.ok, true);
  assert.equal(q.mode, "per_km");
  assert.equal(q.source, "route");
  assert.equal(q.km, 12);
  assert.equal(q.fee, 24);
  assert.equal(roadCalls().length, 1);
  assert.equal(roadCalls()[0].body.coordinates[0][0], -43.17); // [lng, lat] da origem
  const again = await core.quoteTravel("vet1", "22000000", { orsKey: KEY, uid: "t1" });
  assert.equal(again.fee, 24);
  assert.equal(roadCalls().length, 1); // veio do cache
  assert.ok(store.has("travel_cache/20040020_22000000_3"));
});

test("quote: ida e volta dobra; teto por km e teto total valem", async () => {
  seed({ travelRoundTrip: true, travelPerKm: "9" }); // 9 -> teto 3/km
  const q = await core.quoteTravel("vet1", "22000000", { orsKey: KEY });
  assert.equal(q.perKm, 3);
  assert.equal(q.billedKm, 24);
  assert.equal(q.fee, 72); // 24 km × 3
  routeMeters = 20000; // 20 km × 2 × 3 = 120 -> teto 80
  store.delete("travel_cache/20040020_22000000_3");
  const q2 = await core.quoteTravel("vet1", "22000000", { orsKey: KEY });
  assert.equal(q2.fee, 80);
  assert.equal(q2.capped, true);
});

test("quote: fora do raio, taxa fixa e erros", async () => {
  seed(); routeMeters = 45000;
  assert.equal((await core.quoteTravel("vet1", "22000000", { orsKey: KEY })).outOfRange, true);
  seed({ travelModel: "fixed" });
  assert.deepEqual(await core.quoteTravel("vet1", "22000000", { orsKey: KEY }), { ok: true, mode: "fixed" });
  seed();
  assert.equal((await core.quoteTravel("vet1", "123", { orsKey: KEY })).error, "cep_invalido");
  store.delete("vet_origins/vet1");
  assert.equal((await core.quoteTravel("vet1", "22000000", { orsKey: KEY })).error, "origem_ausente");
});

test("quote: serviço de rotas fora do ar => estimativa (linha reta × 1,3), sem cache", async () => {
  seed(); routeMeters = null;
  const q = await core.quoteTravel("vet1", "22000000", { orsKey: KEY });
  assert.equal(q.ok, true);
  assert.equal(q.source, "estimate");
  assert.ok(q.km > 6 && q.km < 12, String(q.km));
  assert.ok(!store.has("travel_cache/20040020_22000000_3"));
});

test("quote: CEP sem coordenadas na BrasilAPI usa a geocodificação do ORS (sem guardar no cache)", async () => {
  seed(); brasilCoords = {}; awesomeCoords = {};
  const q = await core.quoteTravel("vet1", "22000000", { orsKey: KEY });
  assert.equal(q.ok, true);
  assert.ok(calls.some((c) => c.url.includes("/geocode/search")));
  assert.ok(!store.has("cep_geo/22000000")) // plano B (impreciso) não vai ao cache;
  // sem chave do ORS e sem coordenadas: não acha
  seed(); brasilCoords = {}; awesomeCoords = {};
  assert.equal((await core.quoteTravel("vet1", "22000000", {})).error, "destino_nao_encontrado");
});

test("limite diário de consultas externas por usuário", async () => {
  seed();
  store.set(`travel_usage/abuser_${new Date(Date.now() - 3 * 3600e3).toISOString().slice(0, 10).replace(/-/g, "")}`, { n: core.DAILY_LOOKUPS_PER_USER });
  assert.equal((await core.quoteTravel("vet1", "22000000", { orsKey: KEY, uid: "abuser" })).error, "limite");
  // quem já está em cache não gasta cota
  store.set("travel_cache/20040020_22000000_3", { km: 5, at: 1 });
  assert.equal((await core.quoteTravel("vet1", "22000000", { orsKey: KEY, uid: "abuser" })).fee, 10);
});

test("endpoint travelQuote: exige login, valida e nunca devolve coordenadas", async () => {
  seed();
  assert.equal((await post(travelQuote, "bad", { vetId: "vet1", cep: "22000000" })).code, 401);
  assert.equal((await post(travelQuote, "t1", { cep: "22000000" })).code, 400);
  assert.equal((await post(travelQuote, "t1", { vetId: "vet1", cep: "12" })).code, 400);
  const r = await post(travelQuote, "t1", { vetId: "vet1", cep: "22000000" });
  assert.equal(r.code, 200);
  assert.equal(r.body.mode, "per_km");
  assert.ok(!JSON.stringify(r.body).match(/lat|lng|-22\.9/));
});

test("realocação: candidato por km é cotado para o CEP do pedido; fora do raio ou sem CEP sai", async () => {
  seed();
  const area = { estado: "RJ", cidades: [{ nome: "Rio de Janeiro", atende_cidade_toda: true, bairros: [] }] };
  const pub = (extra) => ({
    name: "Dr. Km", crmv: "RJ-1", categories: ["Clínica Geral"], area_atuacao: area, availableDays: [], availableTimes: [],
    isAvailable: true, rating: 4, services: [{ name: "Consulta", price: "60", travelByKm: true }], ...extra,
  });
  store.set("professionals_public/vet1", pub({ travelModel: "per_km", travelPerKm: 2, travelMaxKm: 30 }));
  const day = new Date(Date.now() - 3 * 3600e3 + 3 * 24 * 3600e3);
  const date = `${String(day.getUTCDate()).padStart(2, "0")}/${String(day.getUTCMonth() + 1).padStart(2, "0")}/${day.getUTCFullYear()}`;
  const appt = {
    vetId: "vetX", tutorId: "t1", serviceName: "Consulta", paymentAmount: 100, value: "100,00", date, time: "10:00",
    addrUf: "RJ", addrCity: "Rio de Janeiro", addrNeighborhood: "Centro", addrCep: "22000000", feesDisclosed: true,
  };
  let opts = await rcore.findCandidates(appt, "a1", undefined, { orsKey: KEY });
  assert.equal(opts.length, 1);
  assert.equal(opts[0].price, 84); // 60 + 12 km × 2
  assert.equal(opts[0].travel, 24);
  opts = await rcore.findCandidates({ ...appt, paymentAmount: 80 }, "a1", undefined, { orsKey: KEY });
  assert.equal(opts.length, 0); // 84 > 80 pago
  // serviço que NÃO cobra deslocamento: só o preço do serviço
  store.set("professionals_public/vet1", pub({ travelModel: "per_km", travelPerKm: 2, travelMaxKm: 30, services: [{ name: "Consulta", price: "60" }] }));
  opts = await rcore.findCandidates(appt, "a1", undefined, { orsKey: KEY });
  assert.equal(opts[0].price, 60);
  assert.equal(opts[0].travel, 0);
  store.set("professionals_public/vet1", pub({ travelModel: "per_km", travelPerKm: 2, travelMaxKm: 30 }));
  routeMeters = 45000;
  store.delete("travel_cache/20040020_22000000_3");
  opts = await rcore.findCandidates(appt, "a1", undefined, { orsKey: KEY });
  assert.equal(opts.length, 0); // fora do raio
  routeMeters = 12000;
  opts = await rcore.findCandidates({ ...appt, addrCep: "" }, "a1", undefined, { orsKey: KEY });
  assert.equal(opts.length, 0); // sem CEP não dá para cotar
});

test("coordenada antiga (sem v:3) é refeita; CEPs diferentes na mesma cidade não dão 0 km", async () => {
  seed();
  // origem antiga e imprecisa (centro da cidade) + destino antigo no cache
  store.set("vet_origins/vet1", { lat: -22.9, lng: -43.17, cep: "20040020", at: 1 });
  store.set("cep_geo/22000000", { lat: -22.90642, lng: -43.18223, at: 1 });
  awesomeCoords["20040020"] = { lat: "-22.9050", lng: "-43.1751" };
  routeMeters = 9000;
  const q = await core.quoteTravel("vet1", "22000000", { orsKey: KEY });
  assert.equal(q.km, 9);
  assert.equal(q.fee, 18);
  assert.equal(store.get("vet_origins/vet1").v, 3);
  assert.equal(store.get("cep_geo/22000000").v, 3);
  assert.ok(roadCalls().length === 1);
  const dest = roadCalls()[0].body.coordinates[1];
  assert.equal(dest[0], -43.2); // refeito pela AwesomeAPI, não o centro antigo
});

test("sem AwesomeAPI usa a BrasilAPI", async () => {
  seed(); awesomeCoords = {}; brasilCoords = { "22000000": { latitude: "-22.95", longitude: "-43.20" } };
  const q = await core.quoteTravel("vet1", "22000000", { orsKey: KEY });
  assert.equal(q.ok, true);
  assert.ok(!calls.some((c) => c.url.includes("/geocode/search")));
});
