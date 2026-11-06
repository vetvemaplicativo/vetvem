// Fluxo dos adicionais contra um Firestore falso em memória e um Mercado Pago falso:
// cobrança, cancelamento, webhook (idempotência, valor divergente, pago após cancelar) e repasses.
const test = require("node:test");
const assert = require("node:assert");
const Module = require("node:module");

// ── Firestore falso ──────────────────────────────────────────────────────────
const store = new Map();
let seq = 0;
const SERVER_TS = { __serverTimestamp: true };
const clone = (o) => JSON.parse(JSON.stringify(o));
const resolveTs = (v) => (v && v.__serverTimestamp ? { __ts: Date.now() } : v);
const resolveAll = (o) => Object.fromEntries(Object.entries(o).map(([k, v]) => [k, resolveTs(v)]));
// Timestamp falso com toDate() para pixChangedAt
const withDates = (data) => {
  const d = clone(data);
  if (d.pixChangedAt && typeof d.pixChangedAt === "object" && d.pixChangedAt.__ms) {
    const ms = d.pixChangedAt.__ms; d.pixChangedAt = { toDate: () => new Date(ms) };
  }
  return d;
};

function docRef(path) {
  return {
    id: path.split("/").pop(), path,
    async get() {
      const has = store.has(path);
      return { exists: has, id: path.split("/").pop(), data: () => (has ? withDates(store.get(path)) : undefined), ref: docRef(path) };
    },
    async update(patch) {
      if (!store.has(path)) throw new Error(`update em doc inexistente: ${path}`);
      const cur = store.get(path);
      for (const [k, v] of Object.entries(patch)) cur[k] = clone(resolveTs(v));
      store.set(path, cur);
    },
    async set(data) { store.set(path, clone(resolveAll(data))); },
    collection(name) { return collectionRef(`${path}/${name}`); },
  };
}
function collectionRef(path) {
  return {
    doc(id) { return docRef(`${path}/${id}`); },
    async add(data) { const id = `n${++seq}`; store.set(`${path}/${id}`, clone(resolveAll(data))); return docRef(`${path}/${id}`); },
    where(f, op, v) { return query(path, [[f, v]]); },
    async get() { return query(path, []).get(); },
  };
}
function query(path, filters) {
  return {
    where(f, op, v) { return query(path, [...filters, [f, v]]); },
    async get() {
      const docs = [];
      for (const [p, data] of store.entries()) {
        if (!p.startsWith(path + "/") || p.slice(path.length + 1).includes("/")) continue;
        if (filters.every(([f, v]) => data[f] === v)) docs.push({ id: p.split("/").pop(), data: () => withDates(data), ref: docRef(p) });
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
      set: (ref, data) => ref.set(data),
    }),
  }), { FieldValue: { serverTimestamp: () => SERVER_TS } }),
  auth: () => ({ getUser: async () => { throw new Error("sem auth"); } }),
};
const origLoad = Module._load;
Module._load = function (request, ...rest) {
  if (request === "firebase-admin") return fakeAdmin;
  return origLoad.call(this, request, ...rest);
};
const core = require("../adicionais_core");
Module._load = origLoad;

// ── Mercado Pago falso ───────────────────────────────────────────────────────
function fakeMp({ failAll = false } = {}) {
  const calls = { pix: [], cancel: [] };
  return {
    calls,
    async createPix(account, body, key) {
      calls.pix.push({ account, body, key });
      if (failAll) { const e = new Error("mp fora"); e.response = { data: { message: "mp fora" } }; throw e; }
      return { id: 9000 + calls.pix.length, point_of_interaction: { transaction_data: { qr_code: "000201PIX", qr_code_base64: "QRB64" } } };
    },
    async cancelPayment(account, id) { calls.cancel.push({ account, id }); },
  };
}

// ── cenário ──────────────────────────────────────────────────────────────────
const NOW = Date.parse("2026-11-10T15:10:00-03:00");
const A = "a1"; const X = "x1";
function seed({ appt = {}, extra = {}, vet = {} } = {}) {
  store.clear(); seq = 0;
  store.set(`appointments/${A}`, {
    vetId: "vet1", tutorId: "tut1", vetName: "Dra. Ana", tutorName: "Maria Souza", petName: "Mingau",
    status: "confirmed", paymentStatus: "approved", paymentAccount: "v2", date: "10/11/2026", time: "15:00", ...appt,
  });
  store.set(`appointments/${A}/extras/${X}`, {
    status: "draft", vetId: "vet1", items: [{ name: "Curativo", value: 40 }, { name: "Vacina", value: 60.5 }], ...extra,
  });
  store.set("users/vet1", { name: "Dra. Ana", pixKeys: [{ type: "cpf", key: "111" }], ...vet });
}
const extraOf = () => store.get(`appointments/${A}/extras/${X}`);
const notifsOf = (uid) => [...store.entries()].filter(([p]) => p.startsWith(`notifications/${uid}/pending/`)).map(([, d]) => d);
const charge = (mp, over = {}) => core.createCharge({ appointmentId: A, extraId: X, uid: "vet1", nowMs: NOW, mp, ...over });

// ── cobrança ─────────────────────────────────────────────────────────────────
test("cobrar: soma os itens no servidor, usa a conta do pedido e a referência própria", async () => {
  seed(); const mp = fakeMp();
  const r = await charge(mp);
  assert.equal(r.ok, true);
  assert.equal(r.result.total, 100.5);
  assert.equal(r.result.pixCopyPaste, "000201PIX");
  assert.equal(mp.calls.pix.length, 1);
  assert.equal(mp.calls.pix[0].account, "v2");                       // mesma conta do pedido
  assert.equal(mp.calls.pix[0].body.transaction_amount, 100.5);
  assert.equal(mp.calls.pix[0].body.external_reference, "add:a1:x1"); // não é o id do pedido
  assert.equal(mp.calls.pix[0].body.payer.first_name, "Maria");
  assert.equal(extraOf().status, "awaiting_payment");
  assert.equal(extraOf().pixExpiresAt, NOW + 30 * 60e3);
});

test("cobrar: pedido da conta antiga começa pela v1", async () => {
  seed({ appt: { paymentAccount: undefined } }); const mp = fakeMp();
  await charge(mp);
  assert.equal(mp.calls.pix[0].account, "v1");
});

test("cobrar de novo com o PIX válido devolve o mesmo, sem novo pagamento", async () => {
  seed(); const mp = fakeMp();
  await charge(mp);
  const again = await charge(mp, { nowMs: NOW + 5 * 60e3 });
  assert.equal(again.ok, true);
  assert.equal(again.result.pixCopyPaste, "000201PIX");
  assert.equal(mp.calls.pix.length, 1);
});

test("cobrar com PIX vencido gera outro (chave de idempotência diferente)", async () => {
  seed(); const mp = fakeMp();
  await charge(mp);
  await charge(mp, { nowMs: NOW + 31 * 60e3 });
  assert.equal(mp.calls.pix.length, 2);
  assert.notEqual(mp.calls.pix[0].key, mp.calls.pix[1].key);
});

test("cobrar: só o profissional do pedido, só na janela e só com consulta paga", async () => {
  seed(); let mp = fakeMp();
  assert.equal((await charge(mp, { uid: "outro" })).code, 403);
  seed({ appt: { time: "20:00" } });                                  // abre só às 19:30
  assert.equal((await charge(mp)).code, 422);
  seed({ appt: { paymentStatus: "pending" } });
  assert.equal((await charge(mp)).code, 422);
  seed({ appt: { status: "completed", completedAt: NOW - 3 * 3600e3 } }); // concluída há 3h
  assert.match((await charge(mp)).error, /2 horas/);
  seed({ appt: { status: "completed", completedAt: NOW - 3600e3 } });  // concluída há 1h: ok
  assert.equal((await charge(mp)).ok, true);
  assert.equal(mp.calls.pix.length, 1);
});

test("cobrar: item inválido no rascunho é recusado antes de falar com o MP", async () => {
  seed({ extra: { items: [{ name: "Curativo", value: 0 }] } }); const mp = fakeMp();
  const r = await charge(mp);
  assert.equal(r.code, 422);
  assert.equal(mp.calls.pix.length, 0);
});

test("cobrar: já pago ou cancelado não gera PIX; falha do MP devolve 502 e não muda o status", async () => {
  seed({ extra: { status: "paid" } }); let mp = fakeMp();
  assert.equal((await charge(mp)).code, 409);
  seed({ extra: { status: "cancelled" } });
  assert.equal((await charge(mp)).code, 409);
  seed(); mp = fakeMp({ failAll: true });
  const r = await charge(mp);
  assert.equal(r.code, 502);
  assert.equal(extraOf().status, "draft");
});

// ── cancelar ─────────────────────────────────────────────────────────────────
test("cancelar rascunho: sem chamar o MP", async () => {
  seed(); const mp = fakeMp();
  const r = await core.cancelExtra({ appointmentId: A, extraId: X, uid: "vet1", mp });
  assert.equal(r.ok, true);
  assert.equal(extraOf().status, "cancelled");
  assert.equal(mp.calls.cancel.length, 0);
});

test("cancelar cobrança pendente: tenta cancelar o PIX no MP; pago não cancela; outro vet não cancela", async () => {
  seed(); const mp = fakeMp();
  await charge(mp);
  await core.cancelExtra({ appointmentId: A, extraId: X, uid: "vet1", mp });
  assert.equal(extraOf().status, "cancelled");
  assert.deepEqual(mp.calls.cancel, [{ account: "v2", id: "9001" }]);
  seed({ extra: { status: "paid" } });
  assert.equal((await core.cancelExtra({ appointmentId: A, extraId: X, uid: "vet1", mp })).code, 409);
  seed();
  assert.equal((await core.cancelExtra({ appointmentId: A, extraId: X, uid: "outro", mp })).code, 403);
});

// ── webhook ──────────────────────────────────────────────────────────────────
const approved = (over = {}) => ({ id: 9001, status: "approved", transaction_amount: 100.5, external_reference: "add:a1:x1", ...over });

async function pay(over = {}, nowMs = NOW) {
  return core.settleExtraPayment({ payment: approved(over), account: "v2", nowMs });
}

test("pagamento aprovado: marca pago, enfileira o repasse e avisa tutor e profissional", async () => {
  seed(); await charge(fakeMp());
  const r = await pay();
  assert.equal(r.paid, true);
  assert.equal(extraOf().status, "paid");
  assert.equal(extraOf().paymentAccount, "v2");
  const q = store.get("extra_payouts_queue/x1");
  assert.equal(q.gross, 100.5);
  assert.equal(q.dueAt, NOW + 48 * 3600e3);
  assert.equal(q.processed, false);
  const tutor = notifsOf("tut1"); const vet = notifsOf("vet1");
  assert.equal(tutor.length, 1); assert.equal(vet.length, 1);
  assert.match(tutor[0].body, /R\$ 100,50/);
  assert.equal(tutor[0].tipo, "adicional_pago");
  // o pedido NÃO é tocado
  assert.equal(store.get("appointments/a1").paymentStatus, "approved");
  assert.equal(store.get("appointments/a1").paymentAccount, "v2");
});

test("webhook repetido não duplica notificação nem repasse", async () => {
  seed(); await charge(fakeMp());
  await pay(); const r2 = await pay();
  assert.equal(r2.already, true);
  assert.equal(notifsOf("tut1").length, 1);
  assert.equal([...store.keys()].filter((k) => k.startsWith("extra_payouts_queue/")).length, 1);
});

test("valor pago diferente do total: não marca como pago e registra o problema", async () => {
  seed(); await charge(fakeMp());
  const r = await pay({ transaction_amount: 10 });
  assert.equal(r.mismatch, true);
  assert.equal(extraOf().status, "awaiting_payment");
  assert.match(extraOf().paymentIssue, /difere/);
  assert.equal(notifsOf("tut1").length, 0);
});

test("tutor paga PIX de adicional já cancelado: o dinheiro entrou, então vale como pago", async () => {
  seed(); const mp = fakeMp(); await charge(mp);
  await core.cancelExtra({ appointmentId: A, extraId: X, uid: "vet1", mp });
  await pay();
  assert.equal(extraOf().status, "paid");
  assert.equal(extraOf().paidAfterCancel, true);
});

test("PIX expirado: volta para 'expirado' e o profissional pode gerar outro", async () => {
  seed(); const mp = fakeMp(); await charge(mp);
  await core.settleExtraPayment({ payment: { id: 9001, status: "cancelled", status_detail: "expired", external_reference: "add:a1:x1" }, account: "v2" });
  assert.equal(extraOf().status, "expired");
  const r = await charge(mp, { nowMs: NOW + 40 * 60e3 });
  assert.equal(r.ok, true);
  assert.equal(mp.calls.pix.length, 2);
});

test("pagamento de pedido comum não é tratado como adicional", async () => {
  seed();
  const r = await core.settleExtraPayment({ payment: { id: 1, status: "approved", external_reference: "a1" }, account: "v1" });
  assert.equal(r.handled, false);
});

// ── repasses ─────────────────────────────────────────────────────────────────
test("repasse só D+2 depois do pagamento; taxa do profissional; não duplica; painel não marca o pedido", async () => {
  seed(); await charge(fakeMp()); await pay();
  const early = await core.processExtraPayouts({ nowMs: NOW + 47 * 3600e3 });
  assert.equal(early.count, 0);
  const r = await core.processExtraPayouts({ nowMs: NOW + 49 * 3600e3 });
  assert.equal(r.count, 1);
  const p = store.get("payouts/a1_x1");
  assert.equal(p.gross, 100.5);
  assert.equal(p.feePercent, 15);                 // sem consultas no mês anterior: faixa de 15%
  assert.equal(p.fee, 15.08);
  assert.equal(p.net, 85.42);
  assert.equal(p.status, "due");
  assert.equal(p.appointmentId, "");              // o painel ignora (não marca o pedido como repassado)
  assert.equal(p.parentAppointmentId, "a1");
  assert.match(p.petName, /^Adicionais/);
  assert.equal(p.pixKey, "111 (cpf)");
  assert.equal(extraOf().payoutStatus, "due");
  assert.equal(store.get("extra_payouts_queue/x1").processed, true);
  const again = await core.processExtraPayouts({ nowMs: NOW + 50 * 3600e3 });
  assert.equal(again.count, 0);
});

test("repasse respeita isenção/taxa custom do profissional", async () => {
  seed({ vet: { feeOverride: 0 } }); await charge(fakeMp()); await pay();
  await core.processExtraPayouts({ nowMs: NOW + 49 * 3600e3 });
  const p = store.get("payouts/a1_x1");
  assert.equal(p.fee, 0);
  assert.equal(p.net, 100.5);
});

test("repasse retido se a chave PIX mudou há menos de 48h; entra depois", async () => {
  seed({ vet: { pixChangedAt: { __ms: NOW + 40 * 3600e3 } } }); await charge(fakeMp()); await pay();
  const held = await core.processExtraPayouts({ nowMs: NOW + 49 * 3600e3 });
  assert.equal(held.count, 0); assert.equal(held.held, 1);
  assert.equal(store.get("extra_payouts_queue/x1").processed, false);
  const later = await core.processExtraPayouts({ nowMs: NOW + 90 * 3600e3 });
  assert.equal(later.count, 1);
});
