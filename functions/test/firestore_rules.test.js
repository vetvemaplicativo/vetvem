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
    const items = [{ name: "Curativo", value: 40 }];
    await db.doc("appointments/a1/extras/draft1").set({ status: "draft", vetId: VET, items });
    await db.doc("appointments/a1/extras/pend1").set({ status: "awaiting_payment", vetId: VET, items, total: 40, pixCopyPaste: "x" });
    await db.doc("appointments/a1/extras/paid1").set({ status: "paid", vetId: VET, items, total: 40 });
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
  // provisório: leitura ampla; fase 3: anônimo/telefone não leem pedidos de ninguém
  await (FASE3
    ? assertFails(anon().collection("appointments").where("vetName", "==", "Dra. Ana").get())
    : assertSucceeds(anon().collection("appointments").where("vetName", "==", "Dra. Ana").get()));
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

// ── Adicionais durante o atendimento (só em firestore.rules; a cópia da fase 3 ainda não os tem) ──
const ITEMS = [{ name: "Curativo", value: 40 }];
const extra = (db, id) => db.doc(`appointments/a1/extras/${id}`);
const otherVet = () => as("vet2", "password");

test("adicionais: o profissional do pedido cria rascunho; ninguém mais", { skip: FASE3 }, async () => {
  await assertSucceeds(extra(vet(), "n1").set({ status: "draft", vetId: VET, items: ITEMS, createdAt: serverTimestamp() }));
  await assertFails(extra(otherVet(), "n2").set({ status: "draft", vetId: "vet2", items: ITEMS }));
  await assertFails(extra(tutorPwd(), "n3").set({ status: "draft", vetId: TUTOR, items: ITEMS }));
  await assertFails(extra(anon(), "n4").set({ status: "draft", vetId: "anon1", items: ITEMS }));
});

test("adicionais: o rascunho não nasce já cobrado nem com campos de pagamento", { skip: FASE3 }, async () => {
  await assertFails(extra(vet(), "n5").set({ status: "paid", vetId: VET, items: ITEMS }));
  await assertFails(extra(vet(), "n6").set({ status: "awaiting_payment", vetId: VET, items: ITEMS }));
  await assertFails(extra(vet(), "n7").set({ status: "draft", vetId: VET, items: ITEMS, total: 1, pixCopyPaste: "x" }));
  await assertFails(extra(vet(), "n8").set({ status: "draft", vetId: VET, items: [] }));
  await assertFails(extra(vet(), "n9").set({ status: "draft", vetId: VET, items: Array.from({ length: 21 }, () => ITEMS[0]) }));
});

test("adicionais: edita itens só do rascunho; status, total e PIX são só do servidor", { skip: FASE3 }, async () => {
  await assertSucceeds(extra(vet(), "draft1").update({ items: [...ITEMS, { name: "Vacina", value: 60 }] }));
  await assertFails(extra(vet(), "draft1").update({ status: "paid" }));
  await assertFails(extra(vet(), "draft1").update({ total: 1 }));
  await assertFails(extra(vet(), "pend1").update({ items: ITEMS }));   // já cobrado: congelado
  await assertFails(extra(vet(), "paid1").update({ items: ITEMS }));
  await assertFails(extra(otherVet(), "draft1").update({ items: ITEMS }));
});

test("adicionais: só apaga rascunho", { skip: FASE3 }, async () => {
  await assertSucceeds(extra(vet(), "n1").delete());
  await assertFails(extra(vet(), "pend1").delete());
  await assertFails(extra(vet(), "paid1").delete());
  await assertFails(extra(tutorPwd(), "draft1").delete());
});

test("adicionais: profissional lê tudo; tutor lê só o pago; estranho e anônimo nada", { skip: FASE3 }, async () => {
  await assertSucceeds(extra(vet(), "draft1").get());
  await assertSucceeds(extra(vet(), "pend1").get());
  await assertSucceeds(vet().collection("appointments/a1/extras").get());       // o app do Pro lê a coleção inteira
  await assertFails(otherVet().collection("appointments/a1/extras").get());
  await assertSucceeds(extra(tutorPwd(), "paid1").get());
  await assertFails(extra(tutorPwd(), "draft1").get());
  await assertFails(extra(tutorPwd(), "pend1").get());
  await assertSucceeds(tutorPwd().collection("appointments/a1/extras").where("status", "==", "paid").get());
  await assertFails(tutorPwd().collection("appointments/a1/extras").get());
  await assertFails(extra(otherVet(), "paid1").get());
  await assertFails(extra(anon(), "paid1").get());
  await assertSucceeds(extra(admin(), "pend1").get());
});

// ── Fase 3: appointments só para dono, profissional e admin ─────────────────
const appt = (db, id = "a1") => db.doc(`appointments/${id}`);
const outroTutor = () => as("tutor2", "password");
const outroVet = () => as("vet2", "password", { name: "Dr. Bruno" });
const vetNamed = () => as(VET, "password", { name: "Dra. Ana" });

test("FASE 3 appointments: dono, profissional e admin leem; terceiros não", { skip: !FASE3 }, async () => {
  await assertSucceeds(appt(tutorPwd()).get());
  await assertSucceeds(appt(vet()).get());
  await assertSucceeds(appt(admin()).get());
  await assertFails(appt(outroTutor()).get());
  await assertFails(appt(outroVet()).get());
  await assertFails(appt(anon()).get());
  await assertFails(appt(phone()).get()); // outro uid de celular
  await assertFails(appt(env.unauthenticatedContext().firestore()).get());
});

test("FASE 3 appointments: queries dos apps passam só se filtradas pelo próprio uid", { skip: !FASE3 }, async () => {
  const col = (db) => db.collection("appointments");
  await assertSucceeds(col(tutorPwd()).where("tutorId", "==", TUTOR).get());      // Tutor: Minhas Consultas / home
  await assertSucceeds(col(vet()).where("vetId", "==", VET).get());               // Pro (build que filtrar por vetId)
  await assertSucceeds(col(admin()).get());                                        // painel
  await assertFails(col(tutorPwd()).get());                                        // listar tudo: nunca
  await assertFails(col(tutorPwd()).where("tutorId", "==", "tutor2").get());       // pedidos de outro tutor
  await assertFails(col(tutorPwd()).where("vetId", "==", VET).get());              // horários ocupados por vetId: agora é busyTimes
  await assertFails(col(outroVet()).where("vetId", "==", VET).get());
  await assertFails(col(anon()).where("vetName", "==", "Dra. Ana").get());
});

test("FASE 3 appointments: Pro atual (where vetName == displayName) segue funcionando só para o próprio nome", { skip: !FASE3 }, async () => {
  await assertSucceeds(vetNamed().collection("appointments").where("vetName", "==", "Dra. Ana").get());
  // nome diferente do token: negado (o app só consulta com o displayName da conta)
  await assertFails(outroVet().collection("appointments").where("vetName", "==", "Dra. Ana").get());
  // login por celular/anônimo não usam a cláusula transitória
  await assertFails(as("p9", "phone", { name: "Dra. Ana" }).collection("appointments").where("vetName", "==", "Dra. Ana").get());
});

test("FASE 3 appointments: portal (login por celular) lê e acompanha só o próprio pedido", { skip: !FASE3 }, async () => {
  const ref = await assertSucceeds(phone().collection("appointments").add({
    tutorId: "phone1", vetId: VET, vetName: "Dra. Ana", status: "pending_confirmation",
  }));
  await assertSucceeds(phone().doc(`appointments/${ref.id}`).get());               // StepPix onSnapshot
  await assertFails(as("phone2", "phone").doc(`appointments/${ref.id}`).get());
});

test("FASE 3 appointments: pedido legado sem vetId não é mais editável por qualquer um", { skip: !FASE3 }, async () => {
  await env.withSecurityRulesDisabled((ctx) => ctx.firestore().doc("appointments/legado").set({ tutorId: TUTOR, vetName: "Ronald", status: "completed" }));
  await assertFails(outroVet().doc("appointments/legado").update({ complementos: ["x"] }));
  await assertFails(outroTutor().doc("appointments/legado").update({ complementos: ["x"] }));
  await assertSucceeds(tutorPwd().doc("appointments/legado").update({ rating: 5, comment: "ok" })); // dono avalia
});

test("FASE 3 appointments: escritas legítimas preservadas (tutor avalia/cancela, vet confirma, viewedAt só do vet, uma vez)", { skip: !FASE3 }, async () => {
  await assertSucceeds(tutorPwd().doc("appointments/a1").update({ rating: 4, comment: "bom" }));
  await assertSucceeds(tutorPwd().doc("appointments/a1").update({ status: "cancelled", cancelledBy: "tutor" }));
  await assertFails(tutorPwd().doc("appointments/a1").update({ cancelledBy: "profissional" })); // não mente
  await assertFails(tutorPwd().doc("appointments/a1").update({ paymentStatus: "approved" }));   // campo do servidor
  await assertFails(tutorPwd().doc("appointments/a1").update({ vetId: "vet2" }));
  await assertSucceeds(vet().doc("appointments/a1").update({ status: "confirmed", confirmedAt: new Date() }));
  await assertFails(tutorPwd().doc("appointments/a1").update({ viewedAt: new Date() }));
  await assertSucceeds(vet().doc("appointments/a1").update({ viewedAt: new Date() }));
  await assertFails(vet().doc("appointments/a1").update({ viewedAt: new Date() })); // só uma vez
  await assertFails(outroVet().doc("appointments/a1").update({ status: "confirmed" }));
});

test("FASE 3 appointments: criar só em nome próprio e sem campos do servidor; admin tudo", { skip: !FASE3 }, async () => {
  await assertSucceeds(tutorPwd().collection("appointments").add({ tutorId: TUTOR, vetId: VET, status: "pending_payment" }));
  await assertFails(tutorPwd().collection("appointments").add({ tutorId: "tutor2", vetId: VET }));
  await assertFails(tutorPwd().collection("appointments").add({ tutorId: TUTOR, vetId: VET, historico_status: [] }));
  await assertSucceeds(admin().doc("appointments/a1").update({ status: "cancelled", cancelledBy: "sistema" }));
});

test("FASE 3 appointments/extras: continuam como antes (vet vê tudo, tutor só pagos)", { skip: !FASE3 }, async () => {
  await assertSucceeds(vet().collection("appointments/a1/extras").get());
  await assertFails(outroVet().collection("appointments/a1/extras").get());
  await assertSucceeds(tutorPwd().collection("appointments/a1/extras").where("status", "==", "paid").get());
});
