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
const { chooseRelocation, cancelRelocation, expireRelocations } = require("../realocacao");
const { respondToProposal } = require("../horarios");
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
const notifsOf = (uid) => [...store.entries()].filter(([p]) => p.startsWith(`notifications/${uid}/pending/`)).map(([, d]) => d);
const area = { estado: "RJ", cidades: [{ nome: "Rio de Janeiro", atende_cidade_toda: true, bairros: [] }] };
const pub = (name, price, over = {}) => ({
  name, crmv: "RJ-" + name, categories: ["Clínica Geral"], area_atuacao: area, availableDays: [], availableTimes: [],
  isAvailable: true, rating: 4, services: [{ name: "Consulta", price }], ...over,
});

function seed(apptOver = {}, pubs = {}) {
  store.clear(); httpCalls.length = 0; refundShouldFail = false;
  store.set("professionals_public/vetA", pub("Dra. Ana", "150"));                 // original
  store.set("professionals_public/vetB", pub("Dr. Bruno", "140"));                // mais barato
  store.set("professionals_public/vetC", pub("Dra. Carla", "150"));               // igual
  store.set("professionals_public/vetD", pub("Dr. Davi", "200"));                 // mais caro: fora
  store.set("professionals_public/vetE", pub("Dra. Eva", "100", { categories: ["Ortopedia"] })); // outra especialidade: fora
  store.set("professionals_public/vetF", pub("Dr. Fábio", "100", {
    area_atuacao: { estado: "SP", cidades: [{ nome: "São Paulo", atende_cidade_toda: true, bairros: [] }] } })); // outra região: fora
  for (const [k, v] of Object.entries(pubs)) store.set(`professionals_public/${k}`, v);
  store.set("appointments/a1", {
    vetId: "vetA", vetName: "Dra. Ana", tutorId: "tut1", tutorName: "Bia", petName: "Mingau",
    status: "pending_confirmation", paymentStatus: "approved", paymentId: "999", paymentAmount: 150,
    value: "150,00", serviceName: "Consulta", canRelocate: true, canChooseTimes: true, feesDisclosed: true,
    addrUf: "RJ", addrCity: "Rio de Janeiro", addrNeighborhood: "Tijuca",
    date: inDays(2), time: "10:00", ...apptOver,
  });
}
const ref = () => docRef("appointments/a1");
const appt = () => store.get("appointments/a1");

test("startRelocation: oferece só quem atende (região, especialidade, preço <=), mais barato primeiro", async () => {
  seed();
  const ok = await core.startRelocation(ref(), appt(), { resendKey: "k" });
  assert.equal(ok, true);
  const a = appt();
  assert.equal(a.relocationStatus, "awaiting_tutor");
  assert.deepEqual(a.relocationOptions.map((o) => o.vetId), ["vetB", "vetC"]);
  assert.equal(a.relocationOptions[0].price, 140);
  assert.equal(a.relocationOptions[0].crmv, "RJ-Dr. Bruno");
  assert.equal(a.vetId, "");
  assert.notEqual(a.vetName, "Dra. Ana"); // sai da lista do Pro (que filtra por vetName)
  assert.equal(a.originalVetName, "Dra. Ana");
  assert.equal(a.originalVetId, "vetA");
  assert.equal(a.originalValue, 150);
  assert.equal(a.relocationRound, 1);
  assert.ok(a.relocationDeadline > Date.now() && a.relocationDeadline <= Date.now() + 61 * 60 * 1000);
  assert.ok(a.historico_status.some((e) => e.status === "realocacao_oferecida"));
  assert.equal(notifsOf("tut1")[0].tipo, "realocacao");
  assert.ok(httpCalls.some((c) => c.url.includes("resend") && c.body.to[0] === "tut1@teste.com"));
});

test("startRelocation: sem candidatos, sem a marca, portal, pouco tempo => false e nada muda", async () => {
  seed({}, { vetB: pub("Dr. Bruno", "140", { isAvailable: false }), vetC: pub("Dra. Carla", "150", { services: [{ name: "Vacina", price: "50" }] }) });
  assert.equal(await core.startRelocation(ref(), appt(), {}), false);
  assert.equal(appt().vetId, "vetA");
  seed({ canRelocate: false }); assert.equal(await core.startRelocation(ref(), appt(), {}), false);
  seed({ bookingOrigin: "portal_web" }); assert.equal(await core.startRelocation(ref(), appt(), {}), false);
  seed({ date: inDays(-1), time: "23:59" });
  assert.equal(await core.startRelocation(ref(), appt(), {}), false);
});

test("startRelocation: agenda ocupada tira o candidato; quem não trabalha no horário também", async () => {
  seed({}, { vetC: pub("Dra. Carla", "150", { availableTimes: ["09:00"] }) });
  store.set("appointments/x", { vetId: "vetB", status: "confirmed", date: appt().date, time: "10:00" });
  assert.equal(await core.startRelocation(ref(), appt(), {}), false);
});

test("startRelocation: preço com deslocamento e vários animais conta no limite", async () => {
  seed({ petCount: 2, paymentAmount: 280, value: "280,00" }, {
    vetB: pub("Dr. Bruno", "100", { services: [{ name: "Consulta", price: "100", travelFee: "90" }] }), // 2*100+90=290 > 280
    vetC: pub("Dra. Carla", "100", { services: [{ name: "Consulta", price: "100", travelFee: "80" }] }), // 280 ok
  });
  await core.startRelocation(ref(), appt(), {});
  assert.deepEqual(appt().relocationOptions.map((o) => o.vetId), ["vetC"]);
});

test("escolher: novo profissional recebe o pedido com valor e prazo; estados limpos", async () => {
  seed();
  await core.startRelocation(ref(), appt(), {});
  assert.equal((await call(chooseRelocation, "outro", { appointmentId: "a1", vetId: "vetB" })).code, 403);
  assert.equal((await call(chooseRelocation, "tut1", { appointmentId: "a1", vetId: "vetX" })).code, 400);
  const r = await call(chooseRelocation, "tut1", { appointmentId: "a1", vetId: "vetB" });
  assert.equal(r.code, 200);
  const a = appt();
  assert.equal(a.vetId, "vetB");
  assert.equal(a.vetName, "Dr. Bruno");
  assert.equal(a.value, "140,00");
  assert.equal(a.relocationStatus, "awaiting_vet");
  assert.ok(a.responseDeadline > Date.now());
  assert.equal(a.relocationOptions, undefined);
  assert.equal(a.proposalStatus, undefined);
  assert.equal(a.paymentAmount, 150); // só muda no aceite
  assert.equal(notifsOf("vetB")[0].tipo, "novo_agendamento");
  assert.ok(a.historico_status.some((e) => e.status === "aguardando_confirmacao_novo_profissional"));
});

test("escolher: bloqueios (prazo, agenda tomada, profissional ficou indisponível, trava)", async () => {
  seed(); await core.startRelocation(ref(), appt(), {});
  store.set("appointments/a1", { ...appt(), relocationDeadline: Date.now() - 1000 });
  assert.equal((await call(chooseRelocation, "tut1", { appointmentId: "a1", vetId: "vetB" })).code, 410);

  seed(); await core.startRelocation(ref(), appt(), {});
  store.set("appointments/y", { vetId: "vetB", status: "pending_confirmation", date: appt().date, time: appt().time });
  const r = await call(chooseRelocation, "tut1", { appointmentId: "a1", vetId: "vetB" });
  assert.equal(r.code, 409);
  assert.deepEqual(appt().relocationOptions.map((o) => o.vetId), ["vetC"]); // vetB sai da lista

  seed(); await core.startRelocation(ref(), appt(), {});
  store.set("relocation_locks/vetB|" + appt().date.replace(/\//g, "-") + "|1000", { apptId: "outroPedido", at: Date.now() });
  assert.equal((await call(chooseRelocation, "tut1", { appointmentId: "a1", vetId: "vetB" })).code, 409);
});

test("aceite do novo profissional: estorno parcial da diferença e valor acertado", async () => {
  seed(); await core.startRelocation(ref(), appt(), {});
  await call(chooseRelocation, "tut1", { appointmentId: "a1", vetId: "vetB" });
  store.set("appointments/a1", { ...appt(), status: "confirmed" });
  httpCalls.length = 0;
  await core.settleRelocation(ref(), appt(), { mpToken: "tok", resendKey: "k" });
  const refund = httpCalls.find((c) => c.url.includes("/payments/999/refunds"));
  assert.ok(refund);
  assert.equal(refund.body.amount, 10);
  assert.equal(refund.opts.headers["X-Idempotency-Key"], "relocation-refund-a1");
  const a = appt();
  assert.equal(a.relocationStatus, "done");
  assert.equal(a.paymentAmount, 140);
  assert.equal(a.relocationRefund, 10);
  assert.ok(notifsOf("tut1").some((n) => n.tipo === "realocacao_confirmada" && /10,00/.test(n.body)));
});

test("aceite: preço igual => sem estorno; falha no estorno => marca pendente e avisa o admin", async () => {
  seed(); await core.startRelocation(ref(), appt(), {});
  await call(chooseRelocation, "tut1", { appointmentId: "a1", vetId: "vetC" }); // 150 = 150
  httpCalls.length = 0;
  await core.settleRelocation(ref(), appt(), { mpToken: "tok", resendKey: "k" });
  assert.ok(!httpCalls.some((c) => c.url.includes("/refunds")));
  assert.equal(appt().relocationStatus, "done");

  seed(); await core.startRelocation(ref(), appt(), {});
  await call(chooseRelocation, "tut1", { appointmentId: "a1", vetId: "vetB" });
  refundShouldFail = true; httpCalls.length = 0;
  await core.settleRelocation(ref(), appt(), { mpToken: "tok", resendKey: "k" });
  assert.equal(appt().relocationRefundPending, 10);
  assert.ok(httpCalls.some((c) => c.url.includes("resend") && /parcial falhou/.test(c.body.subject)));
});

test("segunda rodada: quem já foi tentado não volta; limite de tentativas", async () => {
  seed(); await core.startRelocation(ref(), appt(), {});
  await call(chooseRelocation, "tut1", { appointmentId: "a1", vetId: "vetB" });
  // vetB recusa
  store.set("appointments/a1", { ...appt(), status: "rejected" });
  assert.equal(await core.startRelocation(ref(), appt(), {}), true);
  assert.deepEqual(appt().relocationOptions.map((o) => o.vetId), ["vetC"]);
  assert.equal(appt().relocationRound, 2);
  assert.deepEqual([...appt().relocationTried].sort(), ["vetA", "vetB"]);
  // terceira tentativa não existe (limite)
  await call(chooseRelocation, "tut1", { appointmentId: "a1", vetId: "vetC" });
  store.set("appointments/a1", { ...appt(), status: "rejected" });
  assert.equal(await core.startRelocation(ref(), appt(), {}), false);
});

test("cancelRelocation: encerra com motivo para o estorno total", async () => {
  seed(); await core.startRelocation(ref(), appt(), {});
  assert.equal((await call(cancelRelocation, "outro", { appointmentId: "a1" })).code, 403);
  assert.equal((await call(cancelRelocation, "tut1", { appointmentId: "a1" })).code, 200);
  const a = appt();
  assert.equal(a.status, "rejected");
  assert.equal(a.rejectReason, "relocation_declined");
  assert.equal(a.relocationOptions, undefined);
  assert.equal((await call(cancelRelocation, "tut1", { appointmentId: "a1" })).code, 409);
});

test("expireRelocations: tutor não escolheu no prazo => rejeita (estorno) e avisa", async () => {
  seed(); await core.startRelocation(ref(), appt(), {});
  await expireRelocations.run({});
  assert.equal(appt().status, "pending_confirmation"); // ainda no prazo
  store.set("appointments/a1", { ...appt(), relocationDeadline: Date.now() - 1000 });
  await expireRelocations.run({});
  assert.equal(appt().status, "rejected");
  assert.equal(appt().rejectReason, "relocation_expired");
  assert.ok(notifsOf("tut1").some((n) => n.tipo === "realocacao_expirada"));
});

test("respondToProposal 'nenhum serve': com realocação oferece profissionais; sem candidatos, rejeita como antes", async () => {
  seed({ proposalStatus: "awaiting_tutor", proposals: [{ date: inDays(3), time: "09:00" }], proposalDeadline: Date.now() + 3600e3 });
  const r = await call(respondToProposal, "tut1", { appointmentId: "a1", choice: "none" });
  assert.equal(r.code, 200);
  assert.equal(r.body.relocation, true);
  assert.equal(appt().relocationStatus, "awaiting_tutor");
  assert.equal(appt().proposalStatus, "declined");
  assert.equal(appt().status, "pending_confirmation");

  seed({ proposalStatus: "awaiting_tutor", proposals: [{ date: inDays(3), time: "09:00" }], proposalDeadline: Date.now() + 3600e3, canRelocate: false });
  const r2 = await call(respondToProposal, "tut1", { appointmentId: "a1", choice: "none" });
  assert.equal(r2.body.declined, true);
  assert.equal(appt().status, "rejected");
  assert.equal(appt().rejectReason, "tutor_no_option");
});

test("respondToProposal 'cancel': encerra direto com estorno, sem oferecer outros profissionais", async () => {
  seed({ proposalStatus: "awaiting_tutor", proposals: [{ date: inDays(3), time: "09:00" }], proposalDeadline: Date.now() + 3600e3 });
  const r = await call(respondToProposal, "tut1", { appointmentId: "a1", choice: "cancel" });
  assert.equal(r.code, 200);
  assert.equal(r.body.declined, true);
  assert.equal(appt().status, "rejected");
  assert.equal(appt().rejectReason, "tutor_no_option");
  assert.equal(appt().relocationStatus, undefined);
});
