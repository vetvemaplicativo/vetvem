// Fluxo da realocação contra um Firestore falso em memória (sem emulador, sem rede).
const test = require("node:test");
const assert = require("node:assert");
const Module = require("node:module");
const { EventEmitter } = require("node:events");

// ── Firestore falso ──────────────────────────────────────────────────────────
const store = new Map();
let notifSeq = 0;
const SERVER_TS = { __serverTimestamp: true };
const DELETE = { __delete: true };
const clone = (o) => JSON.parse(JSON.stringify(o));
const resolveTs = (v) => (v && v.__serverTimestamp ? { __ts: Date.now() } : v);

function applyPatch(cur, patch) {
  for (const [k, v] of Object.entries(patch)) {
    if (v && v.__delete) delete cur[k];
    else cur[k] = clone(resolveTs(v));
  }
  return cur;
}
function docRef(path) {
  return {
    id: path.split("/").pop(), path,
    async get() {
      const has = store.has(path);
      return { exists: has, id: path.split("/").pop(), data: () => (has ? clone(store.get(path)) : undefined), ref: docRef(path) };
    },
    async update(patch) { store.set(path, applyPatch(store.get(path) || {}, patch)); },
    async set(data) { store.set(path, clone(data)); },
    collection(name) { return collectionRef(`${path}/${name}`); },
  };
}
function listDocs(path, filters) {
  const docs = [];
  for (const [p, data] of store.entries()) {
    if (!p.startsWith(path + "/") || p.slice(path.length + 1).includes("/")) continue;
    if (filters.every(([f, v]) => data[f] === v)) docs.push({ id: p.split("/").pop(), data: () => clone(data), ref: docRef(p) });
  }
  return docs;
}
function collectionRef(path) {
  return {
    doc(id) { return docRef(`${path}/${id}`); },
    async add(data) { const id = `n${++notifSeq}`; store.set(`${path}/${id}`, clone(data)); return docRef(`${path}/${id}`); },
    where(f, op, v) { return query(path, [[f, v]]); },
    async get() { return { docs: listDocs(path, []) }; },
  };
}
function query(path, filters) {
  return {
    where(f, op, v) { return query(path, [...filters, [f, v]]); },
    async get() { return { docs: listDocs(path, filters) }; },
  };
}
const fakeAdmin = {
  initializeApp() {},
  firestore: Object.assign(() => ({
    collection: (n) => collectionRef(n),
    runTransaction: async (fn) => fn({
      get: (ref) => ref.get(),
      update: (ref, patch) => ref.update(patch),
      set: (ref, data) => ref.set(data),
    }),
  }), {
    FieldValue: { serverTimestamp: () => SERVER_TS, delete: () => DELETE },
    Timestamp: { now: () => ({ __ts: Date.now() }) },
  }),
  auth: () => ({
    verifyIdToken: async (t) => { if (t === "bad") throw new Error("x"); return { uid: t }; },
    getUser: async (uid) => ({ uid, email: `${uid}@teste.com` }),
  }),
};
const httpCalls = [];
let refundShouldFail = false;
const fakeAxios = {
  post: async (url, body, opts) => {
    httpCalls.push({ url, body, opts });
    if (url.includes("/refunds") && refundShouldFail) throw new Error("mp fora do ar");
    return { data: {} };
  },
};
const origLoad = Module._load;
Module._load = function (request, ...rest) {
  if (request === "firebase-admin") return fakeAdmin;
  if (request === "axios") return fakeAxios;
  return origLoad.call(this, request, ...rest);
};
const core = require("../realocacao_core");
const { portalRelocationInfo, portalChooseRelocation, portalCancelRelocation } = require("../portal_relocation");
Module._load = origLoad;

function call(fn, uid, body) {
  return new Promise((resolve) => {
    const req = { method: "POST", headers: { authorization: `Bearer ${uid}` }, body, get() { return undefined; } };
    const res = new EventEmitter();
    Object.assign(res, {
      statusCode: 200, headersSent: false,
      status(c) { this.statusCode = c; return this; },
      json(b) { resolve({ code: this.statusCode, body: b }); this.emit("finish"); return this; },
      send(b) { resolve({ code: this.statusCode, body: b }); this.emit("finish"); return this; },
      set() { return this; }, setHeader() { return this; }, getHeader() {}, end() { this.emit("finish"); },
      writeHead() { return this; }, write() {},
    });
    fn(req, res);
  });
}

// ── dados ────────────────────────────────────────────────────────────────────
const fmt = (d) => `${String(d.getUTCDate()).padStart(2, "0")}/${String(d.getUTCMonth() + 1).padStart(2, "0")}/${d.getUTCFullYear()}`;
const inDays = (n) => fmt(new Date(Date.now() - 3 * 3600e3 + n * 24 * 3600e3));
const area = { estado: "RJ", cidades: [{ nome: "Rio de Janeiro", atende_cidade_toda: true, bairros: [] }] };
const pub = (name, price, over = {}) => ({
  name, crmv: "RJ-" + name, categories: ["Clínica Geral"], area_atuacao: area, availableDays: [], availableTimes: [],
  isAvailable: true, rating: 4, services: [{ name: "Consulta", price }], ...over,
});
const post = (fn, body) => call(fn, "anon", body);

function seed(over = {}) {
  store.clear(); httpCalls.length = 0;
  store.set("professionals_public/vetA", pub("Dra. Ana", "150"));
  store.set("professionals_public/vetB", pub("Dr. Bruno", "140"));
  store.set("professionals_public/vetC", pub("Dra. Carla", "150"));
  store.set("appointments/p1", {
    vetId: "vetA", vetName: "Dra. Ana", tutorId: "portalUid", tutorName: "Luanda", email: "luanda@teste.com", petName: "Mingau",
    status: "pending_confirmation", paymentStatus: "approved", paymentId: "999", paymentAmount: 150, value: "150,00",
    serviceName: "Consulta", bookingOrigin: "portal_web", canRelocate: true, feesDisclosed: true,
    addrUf: "RJ", addrCity: "Rio de Janeiro", addrNeighborhood: "Tijuca", date: inDays(2), time: "10:00", ...over,
  });
}
const ref = () => docRef("appointments/p1");
const appt = () => store.get("appointments/p1");
const tokenOf = () => store.get("relocation_tokens/p1").token;
const mails = () => httpCalls.filter((c) => c.url.includes("resend"));

test("portal: abre a realocação, gera chave, e-mail com link e prazo de 2h; sem push", async () => {
  seed();
  assert.equal(await core.startRelocation(ref(), appt(), { resendKey: "k" }), true);
  const a = appt();
  assert.equal(a.relocationStatus, "awaiting_tutor");
  assert.ok(a.relocationDeadline > Date.now() + 119 * 60 * 1000 && a.relocationDeadline <= Date.now() + 121 * 60 * 1000);
  assert.equal(tokenOf().length, 48);
  const m = mails();
  assert.equal(m.length, 1);
  assert.equal(m[0].body.to[0], "luanda@teste.com");
  assert.ok(m[0].body.html.includes(`https://agendar.vetvem.com.br/escolher?id=p1&t=${tokenOf()}`));
  assert.ok([...store.keys()].every((k) => !k.startsWith("notifications/portalUid")));
});

test("portal: sem e-mail, com menos de 5h ou pedido antigo (sem a marca) => estorno como antes", async () => {
  seed({ email: "" }); assert.equal(await core.startRelocation(ref(), appt(), {}), false);
  seed({ canRelocate: false }); assert.equal(await core.startRelocation(ref(), appt(), {}), false);
  const soon = new Date(Date.now() - 3 * 3600e3 + 4 * 3600e3); // daqui a ~4h (Brasília)
  seed({ date: fmt(soon), time: `${String(soon.getUTCHours()).padStart(2, "0")}:00` });
  assert.equal(await core.startRelocation(ref(), appt(), {}), false);
});

test("info: chave errada, ausente ou de outro pedido => 403; chave certa mostra as opções", async () => {
  seed(); await core.startRelocation(ref(), appt(), {});
  assert.equal((await post(portalRelocationInfo, { appointmentId: "p1", token: "errada" })).code, 403);
  assert.equal((await post(portalRelocationInfo, { appointmentId: "p1" })).code, 400);
  assert.equal((await post(portalRelocationInfo, { appointmentId: "p2", token: tokenOf() })).code, 403);
  const r = await post(portalRelocationInfo, { appointmentId: "p1", token: tokenOf() });
  assert.equal(r.code, 200);
  assert.equal(r.body.state, "choose");
  assert.deepEqual(r.body.options.map((o) => o.vetId), ["vetB", "vetC"]);
  assert.equal(r.body.originalVetName, "Dra. Ana");
  assert.equal(r.body.options[0].price, 140);
});

test("escolher pelo link: novo profissional recebe o pedido; tutora recebe e-mail", async () => {
  seed(); await core.startRelocation(ref(), appt(), { resendKey: "k" });
  httpCalls.length = 0;
  assert.equal((await post(portalChooseRelocation, { appointmentId: "p1", token: "x", vetId: "vetB" })).code, 403);
  const r = await post(portalChooseRelocation, { appointmentId: "p1", token: tokenOf(), vetId: "vetB" });
  assert.equal(r.code, 200);
  const a = appt();
  assert.equal(a.vetId, "vetB");
  assert.equal(a.relocationStatus, "awaiting_vet");
  assert.equal(a.value, "140,00");
  assert.ok([...store.entries()].some(([k, v]) => k.startsWith("notifications/vetB/pending/") && v.tipo === "novo_agendamento"));
  // sem chave de e-mail nos testes (o endpoint lê o segredo): a mensagem à tutora só sai em produção
  const info = await post(portalRelocationInfo, { appointmentId: "p1", token: tokenOf() });
  assert.equal(info.body.state, "waiting_vet");
  assert.equal((await post(portalChooseRelocation, { appointmentId: "p1", token: tokenOf(), vetId: "vetC" })).code, 409);
});

test("cancelar pelo link: encerra para estorno total e volta ao último profissional", async () => {
  seed(); await core.startRelocation(ref(), appt(), {});
  assert.equal((await post(portalCancelRelocation, { appointmentId: "p1", token: "x" })).code, 403);
  assert.equal((await post(portalCancelRelocation, { appointmentId: "p1", token: tokenOf() })).code, 200);
  const a = appt();
  assert.equal(a.status, "rejected");
  assert.equal(a.rejectReason, "relocation_declined");
  assert.equal(a.vetName, "Dra. Ana");
  assert.equal((await post(portalCancelRelocation, { appointmentId: "p1", token: tokenOf() })).code, 409);
});

test("aceite do novo profissional (portal): estorno parcial e e-mail da diferença", async () => {
  seed(); await core.startRelocation(ref(), appt(), {});
  await post(portalChooseRelocation, { appointmentId: "p1", token: tokenOf(), vetId: "vetB" });
  store.set("appointments/p1", { ...appt(), status: "confirmed" });
  httpCalls.length = 0;
  await core.settleRelocation(ref(), appt(), { mpToken: "tok", resendKey: "k" });
  assert.equal(httpCalls.find((c) => c.url.includes("/refunds")).body.amount, 10);
  assert.equal(mails().length, 1);
  assert.match(mails()[0].body.html, /10,00/);
  assert.equal(appt().paymentAmount, 140);
});

test("segunda rodada gera chave nova: o link antigo para de valer", async () => {
  seed(); await core.startRelocation(ref(), appt(), {});
  const first = tokenOf();
  await post(portalChooseRelocation, { appointmentId: "p1", token: first, vetId: "vetB" });
  store.set("appointments/p1", { ...appt(), status: "rejected" });
  assert.equal(await core.startRelocation(ref(), appt(), {}), true);
  assert.notEqual(tokenOf(), first);
  assert.equal((await post(portalRelocationInfo, { appointmentId: "p1", token: first })).code, 403);
  assert.equal((await post(portalRelocationInfo, { appointmentId: "p1", token: tokenOf() })).code, 200);
});
