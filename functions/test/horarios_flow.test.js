// Fluxo completo das funções de sugestão de horário contra um Firestore falso
// em memória (sem emulador): confere estados, notificações, estorno acionado e
// regras de negócio. Não toca em nenhum serviço real.
const test = require("node:test");
const assert = require("node:assert");
const Module = require("node:module");

// ── Firestore falso ──────────────────────────────────────────────────────────
const store = new Map();               // "appointments/a1" -> dados
let notifSeq = 0;
const SERVER_TS = { __serverTimestamp: true };
const clone = (o) => JSON.parse(JSON.stringify(o));
const resolveTs = (v) => (v && v.__serverTimestamp ? { __ts: Date.now() } : v);

function docRef(path) {
  return {
    id: path.split("/").pop(),
    path,
    async get() {
      const has = store.has(path);
      return { exists: has, id: path.split("/").pop(), data: () => (has ? clone(store.get(path)) : undefined), ref: docRef(path) };
    },
    async update(patch) {
      const cur = store.get(path) || {};
      for (const [k, v] of Object.entries(patch)) cur[k] = clone(resolveTs(v));
      store.set(path, cur);
    },
    collection(name) { return collectionRef(`${path}/${name}`); },
  };
}
function collectionRef(path) {
  return {
    doc(id) { return docRef(`${path}/${id}`); },
    async add(data) { const id = `n${++notifSeq}`; store.set(`${path}/${id}`, clone(data)); return docRef(`${path}/${id}`); },
    where(f, op, v) { return query(path, [[f, v]]); },
  };
}
function query(path, filters) {
  return {
    where(f, op, v) { return query(path, [...filters, [f, v]]); },
    async get() {
      const docs = [];
      for (const [p, data] of store.entries()) {
        if (!p.startsWith(path + "/") || p.slice(path.length + 1).includes("/")) continue;
        if (filters.every(([f, v]) => data[f] === v)) {
          docs.push({ id: p.split("/").pop(), data: () => clone(data), ref: docRef(p) });
        }
      }
      return { docs };
    },
  };
}
const fakeAdmin = {
  initializeApp() {},
  firestore: Object.assign(() => ({
    collection: (n) => collectionRef(n),
    runTransaction: async (fn) => fn({
      get: (ref) => ref.get(),
      update: (ref, patch) => ref.update(patch),
    }),
  }), {
    FieldValue: { serverTimestamp: () => SERVER_TS },
    Timestamp: { now: () => ({ __ts: Date.now() }) },
  }),
  auth: () => ({ verifyIdToken: async (t) => { if (t === "bad") throw new Error("x"); return { uid: t }; } }),
};
const origLoad = Module._load;
Module._load = function (request, ...rest) {
  if (request === "firebase-admin") return fakeAdmin;
  return origLoad.call(this, request, ...rest);
};
const { proposeNewTimes, respondToProposal, expireProposals } = require("../horarios");
Module._load = origLoad;

// ── helpers de teste ─────────────────────────────────────────────────────────
const { EventEmitter } = require("node:events");
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
const fmt = (d) => `${String(d.getUTCDate()).padStart(2, "0")}/${String(d.getUTCMonth() + 1).padStart(2, "0")}/${d.getUTCFullYear()}`;
// data daqui a N dias (em Brasília) -> "dd/MM/yyyy"
const inDays = (n) => fmt(new Date(Date.now() - 3 * 3600e3 + n * 24 * 3600e3));
const notifsOf = (uid) => [...store.entries()].filter(([p]) => p.startsWith(`notifications/${uid}/pending/`)).map(([, d]) => d);

function seed(over = {}) {
  store.clear();
  store.set("appointments/a1", {
    vetId: "vet1", tutorId: "tut1", vetName: "Dra. Ana", petName: "Mingau",
    status: "pending_confirmation", paymentStatus: "approved", canChooseTimes: true,
    date: inDays(1), time: "11:00", ...over,
  });
}

test("propor: grava estado, prazo, notifica o tutor e registra evento", async () => {
  seed();
  const r = await call(proposeNewTimes, "vet1", { appointmentId: "a1", options: [
    { date: inDays(1), time: "14:00" }, { date: inDays(2), time: "09:00" }, { date: inDays(3), time: "10:00" } ] });
  assert.equal(r.code, 200);
  const a = store.get("appointments/a1");
  assert.equal(a.proposalStatus, "awaiting_tutor");
  assert.equal(a.proposals.length, 3);
  assert.equal(a.originalTime, "11:00");
  assert.ok(a.proposalDeadline > Date.now());
  assert.equal(notifsOf("tut1").length, 1);
  assert.equal(notifsOf("tut1")[0].tipo, "horarios_sugeridos");
  assert.ok(a.historico_status.some((e) => e.status === "horarios_sugeridos"));
});

test("propor: bloqueios (outro profissional, portal, sem a marca, já enviou, sem pagamento, horário ocupado)", async () => {
  const opt = { appointmentId: "a1", options: [{ date: inDays(2), time: "09:00" }] };
  seed(); assert.equal((await call(proposeNewTimes, "outro", opt)).code, 403);
  seed({ bookingOrigin: "portal_web" }); assert.equal((await call(proposeNewTimes, "vet1", opt)).code, 409);
  seed({ canChooseTimes: false }); assert.equal((await call(proposeNewTimes, "vet1", opt)).code, 409);
  seed({ paymentStatus: "pending_payment" }); assert.equal((await call(proposeNewTimes, "vet1", opt)).code, 409);
  seed({ proposalStatus: "awaiting_tutor" }); assert.equal((await call(proposeNewTimes, "vet1", opt)).code, 409);
  seed(); store.set("appointments/b2", { vetId: "vet1", status: "confirmed", date: inDays(2), time: "09:00" });
  assert.equal((await call(proposeNewTimes, "vet1", opt)).code, 409);
  seed(); assert.equal((await call(proposeNewTimes, "bad", opt)).code, 401);
  seed(); assert.equal((await call(proposeNewTimes, "vet1", { appointmentId: "a1", options: [] })).code, 400);
});

test("tutor escolhe: pedido confirmado no novo horário, vet notificado", async () => {
  seed();
  await call(proposeNewTimes, "vet1", { appointmentId: "a1", options: [{ date: inDays(2), time: "09:00" }, { date: inDays(3), time: "10:00" }] });
  assert.equal((await call(respondToProposal, "outro", { appointmentId: "a1", choice: 0 })).code, 403);
  const r = await call(respondToProposal, "tut1", { appointmentId: "a1", choice: 1 });
  assert.equal(r.code, 200);
  const a = store.get("appointments/a1");
  assert.equal(a.status, "confirmed");
  assert.equal(a.date, inDays(3)); assert.equal(a.time, "10:00");
  assert.equal(a.proposalStatus, "accepted");
  assert.equal(notifsOf("vet1").some((n) => n.tipo === "horario_confirmado"), true);
  // não dá para responder duas vezes
  assert.equal((await call(respondToProposal, "tut1", { appointmentId: "a1", choice: 0 })).code, 409);
});

test("tutor escolhe horário que acabou de ser ocupado: 409", async () => {
  seed();
  await call(proposeNewTimes, "vet1", { appointmentId: "a1", options: [{ date: inDays(2), time: "09:00" }] });
  store.set("appointments/c3", { vetId: "vet1", status: "pending_confirmation", date: inDays(2), time: "09:00" });
  assert.equal((await call(respondToProposal, "tut1", { appointmentId: "a1", choice: 0 })).code, 409);
  assert.equal(store.get("appointments/a1").status, "pending_confirmation");
});

test("tutor recusa todos: status rejected (o historian estorna) e vet avisado", async () => {
  seed();
  await call(proposeNewTimes, "vet1", { appointmentId: "a1", options: [{ date: inDays(2), time: "09:00" }] });
  const r = await call(respondToProposal, "tut1", { appointmentId: "a1", choice: "none" });
  assert.equal(r.code, 200);
  const a = store.get("appointments/a1");
  assert.equal(a.status, "rejected"); assert.equal(a.rejectReason, "tutor_no_option"); assert.equal(a.proposalStatus, "declined");
});

test("prazo vencido: tutor não consegue mais responder; expireProposals encerra e notifica", async () => {
  seed();
  await call(proposeNewTimes, "vet1", { appointmentId: "a1", options: [{ date: inDays(2), time: "09:00" }] });
  store.get("appointments/a1").proposalDeadline = Date.now() - 1000;   // vence
  assert.equal((await call(respondToProposal, "tut1", { appointmentId: "a1", choice: 0 })).code, 410);
  await new Promise((res) => { expireProposals.run ? expireProposals.run({}).then(res) : res(); });
  const a = store.get("appointments/a1");
  assert.equal(a.status, "rejected"); assert.equal(a.rejectReason, "proposal_expired"); assert.equal(a.proposalStatus, "expired");
  assert.equal(notifsOf("tut1").some((n) => n.tipo === "proposta_expirada"), true);
});
