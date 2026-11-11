// E-mail do prontuário (portal): regras puras + fluxo com Firestore, Storage e Resend falsos.
const test = require("node:test");
const assert = require("node:assert");
const Module = require("node:module");

const store = new Map();
const DELETE = { __delete: true };
const clone = (o) => JSON.parse(JSON.stringify(o));
function docRef(path) {
  return {
    id: path.split("/").pop(), path,
    async get() { const has = store.has(path); return { exists: has, data: () => (has ? clone(store.get(path)) : undefined), ref: docRef(path) }; },
    async update(patch) {
      const cur = store.get(path);
      for (const [k, v] of Object.entries(patch)) { if (v && v.__delete) delete cur[k]; else cur[k] = clone(v); }
    },
  };
}
const fakeAdmin = {
  initializeApp() {},
  firestore: Object.assign(() => ({
    runTransaction: async (fn) => fn({ get: (r) => r.get(), update: (r, p) => r.update(p) }),
  }), { FieldValue: { delete: () => DELETE } }),
};
const origLoad = Module._load;
Module._load = function (request, ...rest) {
  if (request === "firebase-admin") return fakeAdmin;
  return origLoad.call(this, request, ...rest);
};
const core = require("../prontuario_email_core");
const lib = require("../prontuario_email_lib");
Module._load = origLoad;

const P = "appointments/a1";
const base = () => ({
  bookingOrigin: "portal_web", email: "tutor@x.com", tutorName: "Maria Silva", vetName: "Dra. Ana", vetCrmv: "1234",
  petName: "Rex", date: "10/11/2026", time: "09:00", sentToClient: true,
  prontuario: { peso: "12,5", observacoes: "Tudo <b>bem</b>", vacinas: [{ nome: "V10", proximaDose: "10/12/2026" }], medicamentos: [{ nome: "Dipirona", dosagem: "5ml" }], anexos: [] },
});
function seed(a) { store.clear(); store.set(P, clone(a)); }
function fakes({ failMail = false, files = {} } = {}) {
  const sent = [];
  return {
    sent,
    mail: { async send(k, to, subject, html, att) { if (failMail) throw new Error("resend fora"); sent.push({ to, subject, html, att }); } },
    storage: {
      async download(p) { if (!(p in files)) throw new Error("sem arquivo"); return files[p]; },
      async signedUrl(p) { return `https://signed/${p}`; },
    },
  };
}
const run = (f) => core.handleUpdate({ ref: docRef(P), resendKey: "k", mail: f.mail, storage: f.storage });

test("decide: só portal, com e-mail, sentToClient e prontuário", () => {
  assert.equal(lib.decide(base()), "full");
  assert.equal(lib.decide({ ...base(), bookingOrigin: "app" }), null);
  assert.equal(lib.decide({ ...base(), email: "" }), null);
  assert.equal(lib.decide({ ...base(), sentToClient: false }), null);
  assert.equal(lib.decide({ ...base(), prontuario: undefined }), null);
});

test("primeiro envio: e-mail com conteúdo escapado e reserva gravada", async () => {
  seed(base()); const f = fakes();
  const r = await run(f);
  assert.equal(r.sent, true); assert.equal(r.mode, "full");
  assert.equal(f.sent.length, 1);
  assert.equal(f.sent[0].to, "tutor@x.com");
  assert.match(f.sent[0].html, /Dipirona/); assert.match(f.sent[0].html, /V10/);
  assert.ok(!f.sent[0].html.includes("<b>bem"), "HTML do profissional deve ser escapado");
  assert.ok(store.get(P).prontuarioEmailSentAt);
});

test("idempotente: segundo evento sem novidade não reenvia", async () => {
  seed(base()); const f = fakes();
  await run(f); const r = await run(f);
  assert.equal(r.sent, false); assert.equal(f.sent.length, 1);
});

test("complemento novo gera e-mail curto só com o novo", async () => {
  seed(base()); const f = fakes();
  await run(f);
  const cur = store.get(P); cur.complementos = [{ texto: "Retornar em 7 dias", addedAt: Date.now() }];
  const r = await run(f);
  assert.equal(r.mode, "complement"); assert.equal(f.sent.length, 2);
  assert.match(f.sent[1].html, /Retornar em 7 dias/); assert.ok(!f.sent[1].html.includes("Dipirona"));
  assert.equal((await run(f)).sent, false);
});

test("falha do Resend desfaz a reserva e permite nova tentativa", async () => {
  seed(base());
  const r1 = await run(fakes({ failMail: true }));
  assert.equal(r1.error, true); assert.equal(store.get(P).prontuarioEmailSentAt, undefined);
  const f = fakes(); const r2 = await run(f);
  assert.equal(r2.sent, true); assert.equal(f.sent.length, 1);
});

test("anexos: pequeno vai anexado, acima do limite vira link, ausente é avisado", async () => {
  const a = base();
  a.prontuario.anexos = [{ name: "exame.pdf", path: "p/exame.pdf" }, { name: "grande.pdf", path: "p/grande.pdf" }, { name: "sumiu.pdf", path: "p/sumiu.pdf" }];
  seed(a);
  const f = fakes({ files: { "p/exame.pdf": Buffer.from("abc"), "p/grande.pdf": Buffer.alloc(lib.MAX_ATTACH_BYTES + 1) } });
  const r = await run(f);
  assert.equal(r.attached, 1); assert.equal(r.links, 1); assert.equal(r.failed, 1);
  assert.equal(f.sent[0].att[0].filename, "exame.pdf");
  assert.match(f.sent[0].html, /https:\/\/signed\/p\/grande\.pdf/);
  assert.match(f.sent[0].html, /sumiu\.pdf/);
});
