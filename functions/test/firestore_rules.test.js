// Testa as regras do Firestore contra o emulador. Rodar da raiz do projeto:
//   firebase emulators:exec --only firestore "node --test functions/test/firestore_rules.test.js"
// (precisa de Java no PATH). Por padrão testa firestore.rules (estado provisório:
// leitura cruzada de users só para e-mail/Google/Apple);
// RULES_FILE=docs/seguranca-users-publico/firestore.rules.fase3 testa a fase 3
// (sem leitura cruzada nenhuma).
const test = require("node:test");
const assert = require("node:assert");
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { serverTimestamp } = require("firebase/firestore");

const RULES = path.resolve(__dirname, "../..", process.env.RULES_FILE || "firestore.rules");
const FASE3 = /fase3/.test(RULES);
const VET = "vet1", TUTOR = "tutor1";

let env;
test.before(async () => {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080").split(":");
  env = await initializeTestEnvironment({
    projectId: "vetvem-rules-test",
    firestore: { rules: fs.readFileSync(RULES, "utf8"), host, port: Number(port) },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`users/${VET}`).set({
      role: "professional", accountStatus: "approved", name: "Dra. Ana",
      phone: "21999999999", email: "ana@x.com", pixKeys: [{ key: "123" }],
      address: { street: "Rua A" }, rating: 4, reviewCount: 1, completedCount: 1,
    });
    await db.doc(`users/${TUTOR}`).set({ role: "tutor", name: "Tutor" });
    await db.doc(`professionals_public/${VET}`).set({ name: "Dra. Ana", rating: 4 });
    await db.doc("appointments/a1").set({ tutorId: TUTOR, vetId: VET, vetName: "Dra. Ana", status: "confirmed" });
  });
});
test.after(async () => { await env?.cleanup(); });

// Tokens reais do Firebase sempre trazem firebase.sign_in_provider.
const as = (uid, provider, extra = {}) =>
  env.authenticatedContext(uid, { firebase: { sign_in_provider: provider }, ...extra }).firestore();
const anon = () => as("anon1", "anonymous");
const phone = () => as("phone1", "phone"); // tutor do portal depois do SMS
const tutorPwd = () => as(TUTOR, "password");
const tutorGoogle = () => as(TUTOR, "google.com");
const tutorApple = () => as(TUTOR, "apple.com");
const vet = () => as(VET, "password");
const admin = () => as("adm", "google.com", { admin: true });

const profQueries = (db) => [
  () => db.doc(`users/${VET}`).get(),
  () => db.collection("users").where("role", "==", "professional").get(),
];

// ── Vale na fase provisória E na fase 3 ─────────────────────────────────────
test("login ANÔNIMO e de TELEFONE nunca leem users de profissional (documento nem query)", async () => {
  for (const db of [anon(), phone()]) for (const r of profQueries(db)) await assertFails(r());
});

test("vitrine: qualquer autenticado lê (inclusive anônimo); ninguém escreve", async () => {
  await assertSucceeds(anon().doc(`professionals_public/${VET}`).get());
  await assertSucceeds(phone().collection("professionals_public").get());
  await assertSucceeds(tutorPwd().collection("professionals_public").where("name", "==", "Dra. Ana").get());
  await assertFails(tutorPwd().doc(`professionals_public/${VET}`).set({ name: "x" }));
  await assertFails(vet().doc(`professionals_public/${VET}`).update({ rating: 5 }));
  await assertFails(anon().doc("professionals_public/novo").set({ name: "x" }));
  await assertFails(env.unauthenticatedContext().firestore().doc(`professionals_public/${VET}`).get());
});

test("portal continua funcionando: agendamentos legíveis, lista de espera, criar agendamento após SMS", async () => {
  await assertSucceeds(anon().collection("appointments").where("vetName", "==", "Dra. Ana").get());
  await assertSucceeds(anon().doc("config/app_version_tutor").get());
  await assertSucceeds(anon().collection("waitlist_regiao").add({
    uf: "RJ", cidade: "Niteroi", contato: "tutor@x.com", origem: "portal_web", createdAt: serverTimestamp(),
  }));
  // depois do SMS o uid é do tutor com provider "phone": cria em nome próprio
  await assertSucceeds(phone().collection("appointments").add({
    tutorId: "phone1", vetId: VET, vetName: "Dra. Ana", status: "pending_confirmation",
  }));
  await assertFails(phone().collection("appointments").add({ tutorId: "outro", vetId: VET }));
});

test("dono e admin continuam lendo o users completo", async () => {
  const snap = await assertSucceeds(vet().doc(`users/${VET}`).get());
  assert.equal(snap.data().phone, "21999999999");
  await assertSucceeds(admin().doc(`users/${VET}`).get());
});

test("escritas legítimas preservadas: avaliação por terceiros e perfil pelo dono", async () => {
  await assertSucceeds(tutorPwd().doc(`users/${VET}`).update({ rating: 5, reviewCount: 2, completedCount: 2 }));
  await assertFails(tutorPwd().doc(`users/${VET}`).update({ phone: "0" })); // outros campos: não
  await assertSucceeds(vet().doc(`users/${VET}`).update({ bio: "nova bio" }));
  await assertFails(vet().doc(`users/${VET}`).update({ blocked: false })); // campo admin
});

test("achado: users where name==... (fallback antigo do app) já era negado — não restringe role", async () => {
  await assertFails(tutorPwd().collection("users").where("name", "==", "Dra. Ana").get());
  await assertSucceeds(tutorPwd().collection("professionals_public").where("name", "==", "Dra. Ana").get());
});

test("tutor nunca lê users de outro tutor; anônimo também não", async () => {
  await assertFails(anon().doc(`users/${TUTOR}`).get());
  await assertFails(as("outro", "password").doc(`users/${TUTOR}`).get());
});

// ── Muda na fase 3 ──────────────────────────────────────────────────────────
test(FASE3
  ? "FASE 3: NINGUÉM de fora (nem com e-mail/Google/Apple) lê users de profissional"
  : "provisório: apps (e-mail/Google/Apple) AINDA leem users de profissional — versões antigas dependem disso", async () => {
  for (const db of [tutorPwd(), tutorGoogle(), tutorApple()]) {
    for (const r of profQueries(db)) await (FASE3 ? assertFails(r()) : assertSucceeds(r()));
  }
});
