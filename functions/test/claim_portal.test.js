const test = require("node:test");
const assert = require("node:assert");
const Module = require("node:module");
const lib = require("../claim_portal_lib");

// ── regras puras ─────────────────────────────────────────────────────────────
const NOW = Date.parse("2026-11-11T15:00:00Z");
const app = { uid: "app1", firebase: { sign_in_provider: "password" } };
const phone = { uid: "ph1", firebase: { sign_in_provider: "phone" }, auth_time: NOW / 1000 - 60 };

test("validateTokens: caminho feliz", () => {
  assert.deepEqual(lib.validateTokens(app, phone, NOW), { ok: true, appUid: "app1", phoneUid: "ph1" });
  assert.ok(lib.validateTokens({ ...app, firebase: { sign_in_provider: "google.com" } }, phone, NOW).ok);
});

test("validateTokens: recusa anônimo/telefone no app, não-telefone, mesma conta e SMS antigo", () => {
  assert.equal(lib.validateTokens({ ...app, firebase: { sign_in_provider: "anonymous" } }, phone, NOW).ok, false);
  assert.equal(lib.validateTokens({ ...app, firebase: { sign_in_provider: "phone" } }, phone, NOW).ok, false);
  assert.equal(lib.validateTokens(app, { ...phone, firebase: { sign_in_provider: "password" } }, NOW).ok, false);
  assert.equal(lib.validateTokens(app, { ...phone, uid: "app1" }, NOW).ok, false);
  assert.equal(lib.validateTokens(app, { ...phone, auth_time: NOW / 1000 - 11 * 60 }, NOW).ok, false);
  assert.equal(lib.validateTokens(app, { ...phone, auth_time: undefined }, NOW).ok, false);
  assert.equal(lib.validateTokens(null, phone, NOW).ok, false);
});

test("isClaimable: só concluído do uid do celular", () => {
  assert.ok(lib.isClaimable({ status: "completed", tutorId: "ph1" }, "ph1"));
  assert.equal(lib.isClaimable({ status: "confirmed", tutorId: "ph1" }, "ph1"), false);
  assert.equal(lib.isClaimable({ status: "completed", tutorId: "outro" }, "ph1"), false);
  assert.equal(lib.isClaimable(undefined, "ph1"), false);
});

// ── fluxo com Firestore/Storage falsos ───────────────────────────────────────
const store = new Map();
const clone = (o) => JSON.parse(JSON.stringify(o));
function docRef(path) {
  return {
    id: path.split("/").pop(), path,
    async get() { const has = store.has(path); return { exists: has, data: () => (has ? clone(store.get(path)) : undefined), ref: docRef(path) }; },
    async update(patch) { Object.assign(store.get(path), clone(patch)); },
  };
}
function query(path, filters) {
  return {
    where(f, op, v) { return query(path, [...filters, [f, v]]); },
    async get() {
      const docs = [];
      for (const [p, data] of store.entries()) {
        if (!p.startsWith(path + "/") || p.slice(path.length + 1).includes("/")) continue;
        if (filters.every(([f, v]) => data[f] === v)) docs.push({ id: p.split("/").pop(), data: () => clone(data), ref: docRef(p) });
      }
      return { docs };
    },
  };
}
const fakeAdmin = {
  initializeApp() {},
  firestore: () => ({
    collection: (n) => ({ where: (f, op, v) => query(n, [[f, v]]) }),
    runTransaction: async (fn) => fn({ get: (r) => r.get(), update: (r, p) => r.update(p) }),
  }),
};
const origLoad = Module._load;
Module._load = function (request, ...rest) { return request === "firebase-admin" ? fakeAdmin : origLoad.call(this, request, ...rest); };
const core = require("../claim_portal_core");
Module._load = origLoad;

function seed() {
  store.clear();
  store.set("appointments/a1", { status: "completed", tutorId: "ph1", vetId: "v1" });
  store.set("appointments/a2", { status: "completed", tutorId: "ph1", vetId: "v2" });
  store.set("appointments/a3", { status: "confirmed", tutorId: "ph1", vetId: "v1" });   // não concluído
  store.set("appointments/a4", { status: "completed", tutorId: "outro", vetId: "v1" }); // de outra pessoa
}
function fakeStorage(fail = false) {
  const calls = { set: [] };
  return {
    calls,
    async listFiles(prefix) { if (fail) throw new Error("storage fora"); return prefix === "prontuarios/v1/a1/" ? [{ n: "x.pdf" }, { n: "y.jpg" }] : []; },
    async setTutor(f, uid) { calls.set.push([f.n, uid]); },
  };
}

test("claim: move só os concluídos do celular, reaponta anexos e marca a origem", async () => {
  seed(); const st = fakeStorage();
  const r = await core.claim({ appUid: "app1", phoneUid: "ph1", nowMs: NOW, storage: st });
  assert.equal(r.moved, 2); assert.equal(r.attachments, 2);
  assert.equal(store.get("appointments/a1").tutorId, "app1");
  assert.equal(store.get("appointments/a1").claimedFromPortalUid, "ph1");
  assert.equal(store.get("appointments/a2").tutorId, "app1");
  assert.equal(store.get("appointments/a3").tutorId, "ph1");
  assert.equal(store.get("appointments/a4").tutorId, "outro");
  assert.deepEqual(st.calls.set, [["x.pdf", "app1"], ["y.jpg", "app1"]]);
});

test("claim: segunda chamada não move nada (idempotente)", async () => {
  seed(); await core.claim({ appUid: "app1", phoneUid: "ph1", nowMs: NOW, storage: fakeStorage() });
  const r = await core.claim({ appUid: "app1", phoneUid: "ph1", nowMs: NOW, storage: fakeStorage() });
  assert.equal(r.moved, 0);
});

test("claim: falha no Storage não desfaz a troca dos pedidos", async () => {
  seed();
  const r = await core.claim({ appUid: "app1", phoneUid: "ph1", nowMs: NOW, storage: fakeStorage(true) });
  assert.equal(r.moved, 2); assert.equal(r.attachments, 0);
  assert.equal(store.get("appointments/a1").tutorId, "app1");
});
