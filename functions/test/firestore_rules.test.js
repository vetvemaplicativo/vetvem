// Testa as regras do Firestore contra o emulador. Rodar da raiz do projeto:
//   firebase emulators:exec --only firestore "node --test functions/test/firestore_rules.test.js"
// (precisa de Java no PATH). Por padrão testa firestore.rules (estado atual);
// RULES_FILE=docs/seguranca-users-publico/firestore.rules.fase3 testa a fase 3.
const test = require("node:test");
const assert = require("node:assert");
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");

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
  });
});
test.after(async () => { await env?.cleanup(); });

const anon = () => env.authenticatedContext("anon1", { firebase: { sign_in_provider: "anonymous" } }).firestore();
const tutor = () => env.authenticatedContext(TUTOR).firestore();
const vet = () => env.authenticatedContext(VET).firestore();
const admin = () => env.authenticatedContext("adm", { admin: true }).firestore();

// ── Sempre verdadeiro (fase 1 e 3) ──────────────────────────────────────────
test("vitrine: anônimo e tutor leem; ninguém escreve", async () => {
  await assertSucceeds(anon().doc(`professionals_public/${VET}`).get());
  await assertSucceeds(tutor().collection("professionals_public").get());
  await assertFails(tutor().doc(`professionals_public/${VET}`).set({ name: "x" }));
  await assertFails(vet().doc(`professionals_public/${VET}`).update({ rating: 5 }));
  await assertFails(anon().doc("professionals_public/novo").set({ name: "x" }));
  await assertFails(env.unauthenticatedContext().firestore().doc(`professionals_public/${VET}`).get());
});

test("dono e admin continuam lendo o users completo", async () => {
  const snap = await assertSucceeds(vet().doc(`users/${VET}`).get());
  assert.equal(snap.data().phone, "21999999999");
  await assertSucceeds(admin().doc(`users/${VET}`).get());
});

test("escritas legítimas preservadas: avaliação por terceiros e perfil pelo dono", async () => {
  await assertSucceeds(tutor().doc(`users/${VET}`).update({ rating: 5, reviewCount: 2, completedCount: 2 }));
  await assertFails(tutor().doc(`users/${VET}`).update({ phone: "0" })); // outros campos: não
  await assertSucceeds(vet().doc(`users/${VET}`).update({ bio: "nova bio" }));
  await assertFails(vet().doc(`users/${VET}`).update({ blocked: false })); // campo admin
});

// ── Muda na fase 3 ──────────────────────────────────────────────────────────
test(FASE3 ? "FASE 3: terceiros NÃO leem users de profissional" : "estado atual: terceiros AINDA leem users de profissional (vazamento)", async () => {
  const reads = [
    () => anon().doc(`users/${VET}`).get(),
    () => tutor().doc(`users/${VET}`).get(),
    () => anon().collection("users").where("role", "==", "professional").get(),
    () => tutor().collection("users").where("role", "==", "professional").get(),
  ];
  for (const r of reads) await (FASE3 ? assertFails(r()) : assertSucceeds(r()));
});

test("achado: users where name==... (fallback antigo do app) já era negado — não restringe role", async () => {
  await assertFails(tutor().collection("users").where("name", "==", "Dra. Ana").get());
  await assertSucceeds(tutor().collection("professionals_public").where("name", "==", "Dra. Ana").get());
});

test("tutor nunca lê users de outro tutor", async () => {
  await assertFails(anon().doc(`users/${TUTOR}`).get());
});
