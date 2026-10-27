const test = require("node:test");
const assert = require("node:assert");
const Module = require("node:module");
const store = new Map();
const DEL = { __delete: true };
const doc = (path) => ({
  async get() { return { exists: store.has(path), data: () => (store.has(path) ? JSON.parse(JSON.stringify(store.get(path))) : undefined) }; },
  async update(p) { const c = store.get(path) || {}; for (const [k, v] of Object.entries(p)) { if (v && v.__delete) delete c[k]; else c[k] = v; } store.set(path, c); },
  collection(n) { return { doc: (i) => doc(`${path}/${n}/${i}`), async add(d) { store.set(`${path}/${n}/n${store.size}`, d); } }; },
});
const fake = { initializeApp() {}, firestore: Object.assign(() => ({ collection: (n) => ({ doc: (i) => doc(`${n}/${i}`) }) }), { FieldValue: { serverTimestamp: () => 1, delete: () => DEL } }) };
const orig = Module._load;
Module._load = function (r, ...a) { return r === "firebase-admin" ? fake : orig.call(this, r, ...a); };
const { reopenOnResubmit } = require("../account_review");
Module._load = orig;
const fire = (uid, status) => reopenOnResubmit.run({ params: { uid, docType: "crmv" }, data: { after: { exists: true, data: () => ({ status }) } } });

test("rejeitado que reenvia documento volta para pending e perde o motivo", async () => {
  store.clear(); store.set("users/u1", { role: "professional", accountStatus: "rejected", rejectionReason: "foto ruim" });
  await fire("u1", "submitted");
  assert.equal(store.get("users/u1").accountStatus, "pending");
  assert.equal(store.get("users/u1").rejectionReason, undefined);
  assert.ok([...store.keys()].some((k) => k.startsWith("notifications/u1/pending/")));
});
test("não mexe em aprovado, pendente, tutor nem em documento recusado pelo admin", async () => {
  for (const [u, s] of [[{ role: "professional", accountStatus: "approved" }, "submitted"], [{ role: "professional", accountStatus: "pending" }, "submitted"],
    [{ role: "tutor", accountStatus: "rejected" }, "submitted"], [{ role: "professional", accountStatus: "rejected" }, "rejected"]]) {
    store.clear(); store.set("users/u2", u);
    await fire("u2", s);
    assert.equal(store.get("users/u2").accountStatus, u.accountStatus);
  }
});
