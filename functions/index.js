const { setGlobalOptions } = require("firebase-functions");
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated, onDocumentWritten, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const axios = require("axios");

setGlobalOptions({ maxInstances: 10, region: "southamerica-east1" });

admin.initializeApp();

const MP_SECRET = defineSecret("MP_ACCESS_TOKEN");
const RESEND_SECRET = defineSecret("RESEND_API_KEY");
const { startRelocation, settleRelocation } = require("./realocacao_core");

// ─── Helper: verifica token Firebase e retorna UID ────────────────────────────
async function verifyToken(req, res) {
  const auth = req.headers.authorization || "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : null;
  if (!token) {
    res.status(401).json({ error: "Token não fornecido" });
    return null;
  }
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    return decoded.uid;
  } catch (e) {
    res.status(401).json({ error: "Token inválido" });
    return null;
  }
}

// ─── Helper: verifica token + custom claim admin (ver grantAdmin) ─────────────
async function verifyAdmin(req, res) {
  const auth = req.headers.authorization || "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : null;
  if (!token) {
    res.status(401).json({ error: "Token não fornecido" });
    return null;
  }
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    if (decoded.admin !== true) {
      res.status(403).json({ error: "Acesso restrito a administradores" });
      return null;
    }
    return decoded.uid;
  } catch (e) {
    res.status(401).json({ error: "Token inválido" });
    return null;
  }
}

// ─── Criar pagamento com cartão ───────────────────────────────────────────────
// ─── Valor do pedido calculado NO SERVIDOR ───────────────────────────────────
// Antes o valor cobrado vinha do app (transaction_amount: amount) e ninguém
// conferia com o preço do serviço. Agora o servidor calcula a partir do
// catálogo do profissional (users/{vetId}.services) e do nº de animais do
// pedido. Serviço "por animal" (perAnimal) cobra price no 1º animal e
// additionalPrice (opcional; padrão = price) em cada adicional.
// Compatível com apps antigos: 1 animal => mesmo valor de antes. Se o serviço
// não for achado no catálogo, mantém o valor enviado pelo app (e registra aviso).
const { priceForService, toNum, petLabel } = require("./appointment_amount");
const { quoteTravel, ORS_SECRET, AWESOME_SECRET } = require("./travel_core");
const TRAVEL_ERRORS = {
  fora_do_raio: "Este profissional não atende o seu endereço (fora do raio de deslocamento).",
  deslocamento_indisponivel: "Não foi possível calcular o deslocamento agora. Tente novamente.",
};

async function computeAppointmentAmount(appt, clientAmount) {
  const fallback = { amount: Number(clientAmount), source: "client", count: 1 };
  try {
    const vetId = appt.vetId;
    const name = String(appt.serviceName || "").trim();
    if (!vetId || !name) return fallback;
    const vet = (await admin.firestore().collection("users").doc(vetId).get()).data() || {};
    const svc = (vet.services || []).find((x) => String((x && x.name) || "").trim() === name);
    if (!svc) return { ...fallback, source: "client-sem-servico" };
    // Deslocamento por km: só quando o app declarou que MOSTROU o valor calculado (travelQuoted)
    // para o CEP do tutor. Cliente antigo segue na taxa fixa do serviço, como antes.
    // O profissional por km escolhe, serviço a serviço, se cobra deslocamento (svc.travelByKm).
    const byKmVet = vet.travelModel === "per_km";
    let opts;
    if (byKmVet && appt.feesDisclosed === true && appt.travelQuoted === true && svc.travelByKm !== true) {
      opts = { travelFee: 0 };
    } else if (appt.feesDisclosed === true && appt.travelQuoted === true && appt.addrCep && (!byKmVet || svc.travelByKm === true)) {
      let q;
      try {
        q = await quoteTravel(vetId, appt.addrCep, { uid: appt.tutorId, vet });
      } catch (e) {
        console.error("computeAppointmentAmount deslocamento:", e.message);
        q = { ok: false };
      }
      if (!q.ok) return { ...fallback, source: "deslocamento", error: "deslocamento_indisponivel" };
      if (q.mode === "per_km") {
        if (q.outOfRange) return { ...fallback, source: "deslocamento", error: "fora_do_raio" };
        opts = { travelFee: q.fee };
      }
    }
    const priced = priceForService(svc, appt, opts);
    if (!priced) return { ...fallback, source: "client-preco-zero" };
    const { amount: total, count, travel } = priced;
    return { amount: total, source: "server", count, travel };
  } catch (e) {
    console.error("computeAppointmentAmount:", e.message);
    return fallback;
  }
}

exports.createPayment = onRequest(
  { region: "southamerica-east1", secrets: [MP_SECRET, ORS_SECRET, AWESOME_SECRET], cors: true },
  async (req, res) => {
    if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

    const uid = await verifyToken(req, res);
    if (!uid) return;

    const { appointmentId, amount, description, email, token, paymentMethodId, installments, customerId, cpf, firstName, lastName } = req.body;

    if (!appointmentId || !amount || !token || !paymentMethodId) {
      return res.status(400).json({ error: "Dados de pagamento incompletos" });
    }

    const MP_ACCESS_TOKEN = MP_SECRET.value();

    try {
      const apptForAmount = (await admin.firestore().collection("appointments").doc(appointmentId).get()).data() || {};
      const priced = await computeAppointmentAmount(apptForAmount, amount);
      if (priced.error) return res.status(422).json({ error: TRAVEL_ERRORS[priced.error], code: priced.error });
      const finalAmount = priced.amount > 0 ? priced.amount : Number(amount);
      if (Math.abs(finalAmount - Number(amount)) > 0.009) {
        console.warn(`valor do app (${amount}) difere do calculado (${finalAmount}, ${priced.source}) em ${appointmentId}`);
      }
      // De 1 a 12 parcelas; os juros ficam por conta do tutor (o MP soma ao total pago).
      const safeInstallments = Math.min(12, Math.max(1, Math.floor(Number(installments)) || 1));
      const response = await axios.post(
        "https://api.mercadopago.com/v1/payments",
        {
          transaction_amount: finalAmount,
          token,
          description,
          installments: safeInstallments,
          payment_method_id: paymentMethodId,
          // Cartão salvo no cofre MP: paga como customer (dados já estão no
          // cofre); senão, guest com dados completos — CPF e nome reduzem
          // falsos positivos do antifraude.
          payer: customerId
            ? { type: "customer", id: customerId }
            : {
                email,
                ...(firstName ? { first_name: firstName } : {}),
                ...(lastName ? { last_name: lastName } : {}),
                ...(cpf ? { identification: { type: "CPF", number: cpf } } : {}),
              },
          external_reference: appointmentId,
          notification_url: `https://southamerica-east1-vetvem-18bf4.cloudfunctions.net/mpWebhook`,
        },
        {
          headers: {
            Authorization: `Bearer ${MP_ACCESS_TOKEN}`,
            "Content-Type": "application/json",
            "X-Idempotency-Key": appointmentId,
          },
        }
      );

      const payment = response.data;
      console.log(`createPayment: ${payment.id} → ${payment.status} (${payment.status_detail})`);

      await admin.firestore().collection("appointments").doc(appointmentId).update({
        paymentId: String(payment.id),
        paymentStatus: payment.status,
        paymentMethod: paymentMethodId,
        paymentAmount: finalAmount,
        paymentInstallments: safeInstallments,
        ...(payment.transaction_details && Number(payment.transaction_details.total_paid_amount) > 0
          ? { paymentTotalPaid: Number(payment.transaction_details.total_paid_amount) }
          : {}),
        paymentDate: admin.firestore.FieldValue.serverTimestamp(),
      });

      return res.json({
        result: {
          status: payment.status,
          statusDetail: payment.status_detail,
          paymentId: payment.id,
        },
      });
    } catch (error) {
      const mpError = error.response?.data;
      console.error("MP Error:", JSON.stringify(mpError));
      return res.status(500).json({ error: mpError?.message || "Erro ao processar pagamento" });
    }
  }
);

// ─── Criar pagamento PIX ──────────────────────────────────────────────────────
exports.createPixPayment = onRequest(
  { region: "southamerica-east1", secrets: [MP_SECRET, ORS_SECRET, AWESOME_SECRET], cors: true },
  async (req, res) => {
    if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

    const uid = await verifyToken(req, res);
    if (!uid) return;

    const { appointmentId, amount, description, email, firstName, lastName, cpf } = req.body;

    if (!appointmentId || !amount || !email) {
      return res.status(400).json({ error: "Dados incompletos" });
    }

    const MP_ACCESS_TOKEN = MP_SECRET.value();

    try {
      const apptForAmount = (await admin.firestore().collection("appointments").doc(appointmentId).get()).data() || {};
      const priced = await computeAppointmentAmount(apptForAmount, amount);
      if (priced.error) return res.status(422).json({ error: TRAVEL_ERRORS[priced.error], code: priced.error });
      const finalAmount = priced.amount > 0 ? priced.amount : Number(amount);
      if (Math.abs(finalAmount - Number(amount)) > 0.009) {
        console.warn(`valor do app (${amount}) difere do calculado (${finalAmount}, ${priced.source}) em ${appointmentId}`);
      }
      // Tutor voltou à tela de pagamento: se o PIX anterior ainda vale,
      // devolve o mesmo código em vez de gerar outro (evita pagamento duplo).
      const apptRef = admin.firestore().collection("appointments").doc(appointmentId);
      const existing = (await apptRef.get()).data() || {};
      if (
        existing.tutorId === uid &&
        existing.paymentStatus === "pending" &&
        existing.pixCopyPaste &&
        existing.pixExpiresAt &&
        existing.pixExpiresAt > Date.now() + 60 * 1000
        && Math.abs(Number(existing.paymentAmount || 0) - finalAmount) < 0.01
      ) {
        return res.json({
          result: {
            status: "pending",
            paymentId: existing.paymentId,
            pixCopyPaste: existing.pixCopyPaste,
            pixQrCodeBase64: existing.pixQrCodeBase64,
            pixExpiresAt: existing.pixExpiresAt,
          },
        });
      }

      const pixExpiresAt = Date.now() + 30 * 60 * 1000;
      const response = await axios.post(
        "https://api.mercadopago.com/v1/payments",
        {
          transaction_amount: finalAmount,
          description,
          payment_method_id: "pix",
          payer: {
            email,
            first_name: firstName || "Cliente",
            last_name: lastName || "VetVem",
            identification: { type: "CPF", number: cpf || "00000000000" },
          },
          external_reference: appointmentId,
          date_of_expiration: new Date(pixExpiresAt).toISOString(),
          notification_url: `https://southamerica-east1-vetvem-18bf4.cloudfunctions.net/mpWebhook`,
        },
        {
          headers: {
            Authorization: `Bearer ${MP_ACCESS_TOKEN}`,
            "Content-Type": "application/json",
            // Chave única por geração: com chave fixa o MP devolveria sempre o
            // PIX antigo (já expirado) quando o tutor volta para pagar.
            "X-Idempotency-Key": `pix-${appointmentId}-${pixExpiresAt}`,
          },
        }
      );

      const payment = response.data;
      const pixData = payment.point_of_interaction?.transaction_data;

      await apptRef.update({
        paymentId: String(payment.id),
        paymentStatus: payment.status,
        paymentMethod: "pix",
        paymentAmount: finalAmount,
        paymentDate: admin.firestore.FieldValue.serverTimestamp(),
        pixCopyPaste: pixData?.qr_code || null,
        pixQrCodeBase64: pixData?.qr_code_base64 || null,
        pixExpiresAt,
      });

      return res.json({
        result: {
          status: payment.status,
          paymentId: payment.id,
          pixCopyPaste: pixData?.qr_code,
          pixQrCodeBase64: pixData?.qr_code_base64,
          pixExpiresAt,
        },
      });
    } catch (error) {
      const mpError = error.response?.data;
      console.error("PIX Error:", JSON.stringify(mpError));
      return res.status(500).json({ error: mpError?.message || "Erro ao gerar PIX" });
    }
  }
);

// ─── Webhook do Mercado Pago ──────────────────────────────────────────────────
exports.mpWebhook = onRequest(
  { region: "southamerica-east1", secrets: [MP_SECRET, RESEND_SECRET] },
  async (req, res) => {
    if (req.method !== "POST") return res.status(405).send("Method Not Allowed");

    const { type, data } = req.body;

    if (type === "payment" && data?.id) {
      try {
        const MP_ACCESS_TOKEN = MP_SECRET.value();
        const mpRes = await axios.get(
          `https://api.mercadopago.com/v1/payments/${data.id}`,
          { headers: { Authorization: `Bearer ${MP_ACCESS_TOKEN}` } }
        );

        const payment = mpRes.data;
        const appointmentId = payment.external_reference;

        if (appointmentId) {
          const ref = admin.firestore().collection("appointments").doc(appointmentId);
          await ref.update({
            paymentStatus: payment.status,
            paymentStatusDetail: payment.status_detail,
            paymentUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          if (payment.status === "approved") {
            const snap = await ref.get();
            const current = snap.data();

            // Corrida: o PIX (portal ou app) pode cair depois do vet já ter
            // recusado (appointmentHistorian não reembolsou na hora porque
            // ainda não tinha sido pago). Confere o estado atual e reembolsa.
            if (current && current.status === "rejected") {
              await handleRejectedPayment(
                ref,
                { ...current, paymentStatus: "approved", paymentId: String(payment.id) },
                MP_ACCESS_TOKEN,
                RESEND_SECRET.value()
              );
            } else if (
              current &&
              current.status === "pending_confirmation" &&
              current.vetId &&
              !current.vetNotifiedAt
            ) {
              // O vet só é avisado depois do pagamento aprovado (portal e app).
              // Feito aqui e não no app do tutor: quem paga o PIX pelo app do
              // banco fecha o VetVem e o aviso do cliente nunca sairia.
              await admin
                .firestore()
                .collection("notifications")
                .doc(current.vetId)
                .collection("pending")
                .add({
                  title: "🗓️ Novo agendamento pago!",
                  body: `${current.tutorName || "Um tutor"} agendou ${current.serviceName || "uma consulta"} para ${petLabel(current, "o pet")} em ${current.date} às ${current.time}. Confirme em até ${RESPONSE_DEADLINE_MINUTES / 60} horas ou a solicitação expira.`,
                  read: false,
                  createdAt: admin.firestore.FieldValue.serverTimestamp(),
                  tipo: "novo_agendamento",
                  appointmentId,
                });
              await ref.update({
                vetNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
            }
          }
        }
      } catch (e) {
        console.error("Webhook error:", e.message);
      }
    }

    res.status(200).send("OK");
  }
);

// ─── Repasses D+2 — resumo diário para o administrador ───────────────────────
// Roda todo dia às 08:00 (horário de Brasília). Encontra consultas completadas
// há 2+ dias com pagamento aprovado e ainda sem repasse, calcula o valor líquido
// (descontando a taxa do app), grava em `payouts` e envia notificação ao admin
// com valores e chaves PIX prontos para transferência manual.

// Taxa regressiva por volume: consultas concluídas E pagas no MÊS ANTERIOR
// definem a taxa do mês atual do profissional.
//   1–9 → 15%  |  10–19 → 12%  |  20+ → 10%
// IMPORTANTE: mesma tabela existe no app Pro (home_controller.dart,
// feePercentFor) — mudanças aqui precisam ser replicadas lá.
// Faixas padrão; editáveis no painel admin via doc config/fees {tiers:[{min,pct}]}
const DEFAULT_TIERS = [{ min: 20, pct: 10 }, { min: 10, pct: 12 }, { min: 0, pct: 15 }];

async function loadFeeTiers(db) {
  try {
    const cfg = await db.collection("config").doc("fees").get();
    const tiers = cfg.data()?.tiers;
    if (Array.isArray(tiers) && tiers.length > 0) {
      return tiers.slice().sort((a, b) => b.min - a.min);
    }
  } catch (_) {}
  return DEFAULT_TIERS;
}

function feePercentFor(completedLastMonth, tiers) {
  for (const t of tiers) if (completedLastMonth >= t.min) return t.pct;
  return 15;
}

const PIX_HOLD_HOURS = 48; // carência dos repasses após trocar a chave PIX
const ADMIN_EMAIL ="ronalddesouzabr@gmail.com"; // conta que recebe o resumo diário

function parseApptDate(s) {
  // "23/06/2026" → Date
  const p = (s || "").split("/");
  if (p.length < 3) return null;
  const d = new Date(`${p[2]}-${p[1].padStart(2, "0")}-${p[0].padStart(2, "0")}T12:00:00-03:00`);
  return isNaN(d.getTime()) ? null : d;
}

// Data + hora do agendamento, já no fuso de Brasília (-03:00), sem usar
// Date.setHours() — setHours() muda a hora no fuso do SERVIDOR (UTC nas
// Cloud Functions), não no de Brasília, o que deslocava o horário real da
// consulta em 3h e fazia o timeout automático (apptStarted) disparar cedo
// demais (bug encontrado em 2026-09-14: agendamento pra 14:00 sendo
// cancelado por "hora já chegada" pouco depois das 11h).
function parseApptDateTime(dateStr, timeStr) {
  const p = (dateStr || "").split("/");
  if (p.length < 3) return null;
  const [hh, mm] = (timeStr || "23:59").split(":").map((v) => parseInt(v, 10));
  const h = Number.isFinite(hh) ? hh : 23;
  const m = Number.isFinite(mm) ? mm : 59;
  const d = new Date(
    `${p[2]}-${p[1].padStart(2, "0")}-${p[0].padStart(2, "0")}` +
    `T${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}:00-03:00`
  );
  return isNaN(d.getTime()) ? null : d;
}

function parseValue(v, fallbackStr) {
  if (typeof v === "number") return v;
  const cleaned = String(fallbackStr || "").replace("R$", "").replace(/\s/g, "").replace(/\./g, "").replace(",", ".");
  return parseFloat(cleaned) || 0;
}

exports.dailyPayouts = onSchedule(
  { schedule: "0 8 * * *", timeZone: "America/Sao_Paulo", region: "southamerica-east1" },
  async () => {
    const db = admin.firestore();
    const now = new Date();
    const cutoff = new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000); // D+2

    const snap = await db.collection("appointments")
      .where("status", "==", "completed").get();

    // Mês anterior (para a taxa regressiva por volume)
    const prevMonthStart = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const thisMonthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const lastMonthCountByVet = {};

    const due = [];
    for (const doc of snap.docs) {
      const d = doc.data();
      if (d.paymentStatus !== "approved") continue; // só consultas pagas
      const apptDate = parseApptDate(d.date);
      // Conta consultas concluídas+pagas do mês anterior por vet
      if (apptDate && d.vetId &&
          apptDate >= prevMonthStart && apptDate < thisMonthStart) {
        lastMonthCountByVet[d.vetId] = (lastMonthCountByVet[d.vetId] || 0) + 1;
      }
      if (d.payoutStatus) continue;                 // já processada
      if (!apptDate || apptDate > cutoff) continue; // ainda não venceu o D+2
      due.push({ id: doc.id, ...d });
    }

    if (due.length === 0) {
      console.log("dailyPayouts: nenhum repasse devido hoje.");
      return;
    }

    // Faixas de taxa (config/fees, editável no painel) + dados por vet
    const tiers = await loadFeeTiers(db);
    const vetIds = [...new Set(due.map((a) => a.vetId).filter(Boolean))];
    const pixByVet = {};
    const heldVets = new Set(); // chave PIX trocada há pouco: segura o repasse
    const overrideByVet = {}; // isenção/taxa custom (com prazo opcional)
    for (const vetId of vetIds) {
      const vetDoc = await db.collection("users").doc(vetId).get();
      const d = vetDoc.data() || {};
      const keys = d.pixKeys || [];
      const chg = d.pixChangedAt && d.pixChangedAt.toDate ? d.pixChangedAt.toDate() : null;
      if (chg && Date.now() - chg.getTime() < PIX_HOLD_HOURS * 3600 * 1000) heldVets.add(vetId);
      pixByVet[vetId] = keys.length > 0 ? `${keys[0].key} (${keys[0].type})` : "sem chave PIX cadastrada";
      if (d.feeOverride != null) {
        const until = d.feeOverrideUntil;
        const expired = until && until.toDate && until.toDate() < new Date();
        if (!expired) overrideByVet[vetId] = d.feeOverride;
      }
    }

    // Carência de segurança: repasses de quem trocou a chave PIX há menos de
    // PIX_HOLD_HOURS ficam sem payoutStatus e entram sozinhos num dia seguinte.
    const heldCount = due.filter((a) => heldVets.has(a.vetId)).length;
    for (let i = due.length - 1; i >= 0; i--) {
      if (heldVets.has(due[i].vetId)) due.splice(i, 1);
    }
    if (heldCount > 0) {
      console.log(`dailyPayouts: ${heldCount} repasse(s) retido(s) por troca recente de chave PIX.`);
      try {
        const adminUser = await admin.auth().getUserByEmail(ADMIN_EMAIL);
        await db.collection("notifications").doc(adminUser.uid).collection("pending").add({
          title: `🔒 ${heldCount} repasse(s) retido(s) por troca de chave PIX`,
          body: `Carência de ${PIX_HOLD_HOURS}h após a troca. Entram automaticamente depois.`,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
    if (due.length === 0) return;

    // Grava payouts e marca appointments
    const lines = [];
    let total = 0;
    const batch = db.batch();
    for (const a of due) {
      const gross = parseValue(a.paymentAmount, a.value);
      const feePercent = overrideByVet[a.vetId] ??
          feePercentFor(lastMonthCountByVet[a.vetId] || 0, tiers);
      const fee = +(gross * feePercent / 100).toFixed(2);
      const net = +(gross - fee).toFixed(2);
      total += net;

      batch.set(db.collection("payouts").doc(a.id), {
        appointmentId: a.id,
        vetId: a.vetId || "",
        vetName: a.vetName || "",
        petName: petLabel(a, ""),
        appointmentDate: a.date || "",
        gross, fee, net,
        feePercent,
        pixKey: pixByVet[a.vetId] || "sem chave PIX cadastrada",
        status: "due", // atualize para "paid" quando fizer a transferência
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      batch.update(db.collection("appointments").doc(a.id), {
        payoutStatus: "due",
        payoutNet: net,
        payoutFee: fee,
      });

      const netStr = net.toFixed(2).replace(".", ",");
      lines.push(`${a.vetName || "Vet"}: R$ ${netStr} (taxa ${feePercent}%) — PIX: ${pixByVet[a.vetId] || "sem chave"}`);
    }
    await batch.commit();

    // Notifica o admin com o resumo
    try {
      const adminUser = await admin.auth().getUserByEmail(ADMIN_EMAIL);
      const totalStr = total.toFixed(2).replace(".", ",");
      await db.collection("notifications").doc(adminUser.uid).collection("pending").add({
        title: `💸 ${due.length} repasse(s) hoje — total R$ ${totalStr}`,
        body: lines.join("\n"),
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      console.error("dailyPayouts: falha ao notificar admin:", e.message);
    }

    console.log(`dailyPayouts: ${due.length} repasses, total R$ ${total.toFixed(2)}`);
  }
);

// ─── Push notification (FCM) ──────────────────────────────────────────────────
// Toda notificação criada em notifications/{uid}/pending vira um push real.
// Os apps (tutor e Pro) salvam o token FCM em users/{uid}.fcmToken no login.
// Assim, TODOS os sendTo existentes ganham push sem mudar nenhuma chamada.

exports.sendPush = onDocumentCreated(
  { document: "notifications/{uid}/pending/{notifId}", region: "southamerica-east1" },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const uid = event.params.uid;
    const tipo = data.tipo || null;
    const appointmentId = data.appointmentId || null;

    // Funil: "notificado" — só para a notificação de solicitação nova indo
    // ao profissional. Registrado antes da checagem de token: "notificado"
    // significa que a solicitação chegou à caixa dele, mesmo que o push em
    // si falhe (ele ainda vê no app ao abrir).
    if (tipo === "novo_agendamento" && appointmentId) {
      try {
        const apptRef = admin.firestore().collection("appointments").doc(appointmentId);
        const apptSnap = await apptRef.get();
        const a = apptSnap.data() || {};
        // Antifraude: só loga se o destinatário é mesmo o vet da solicitação
        // e ela ainda está pendente (evita poluir o funil com replays).
        if (apptSnap.exists && (!a.vetId || a.vetId === uid) &&
            a.status === "pending_confirmation") {
          await logEvent(apptRef, "notificado", "cloud_function", uid, null);
        }
      } catch (e) { console.error("sendPush/notificado:", e.message); }
    }

    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    const user = userDoc.data() || {};
    const token = user.fcmToken;
    if (!token) {
      console.log(`sendPush: usuário ${uid} sem fcmToken, pulando.`);
      return;
    }
    // Canal Android correto por app (tutor × Pro)
    const channelId = user.role === "professional"
      ? "vetvem_pro_channel_v2"
      : "vetvem_channel_v2";

    try {
      await admin.messaging().send({
        token,
        notification: {
          title: data.title || "VetVem",
          body: data.body || "",
        },
        // Payload de dados para deep-link no app (abrir direto no agendamento)
        data: {
          ...(tipo ? { tipo } : {}),
          ...(appointmentId ? { appointmentId } : {}),
        },
        android: {
          priority: "high",
          notification: {
            channelId,
            sound: "default",
            defaultVibrateTimings: true,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      });
      // Marca como entregue via push — o app não re-exibe ao abrir
      await event.data.ref.update({ pushed: true });
      console.log(`sendPush: push enviado para ${uid}`);
    } catch (e) {
      // Token inválido/expirado: remove para o app regravar no próximo login
      if (e.code === "messaging/registration-token-not-registered" ||
          e.code === "messaging/invalid-registration-token") {
        await admin.firestore().collection("users").doc(uid)
          .update({ fcmToken: admin.firestore.FieldValue.delete() });
        console.log(`sendPush: token inválido de ${uid} removido.`);
      } else {
        console.error("sendPush error:", e.message);
      }
    }
  }
);

// ─── Salvar cartão no cofre do Mercado Pago ───────────────────────────────────
// Recebe um card_token de uso único, garante um customer MP para o usuário
// (por e-mail) e anexa o cartão a ele. Nas próximas compras o app só pede o
// CVV — o número completo nunca é armazenado por nós (PCI: fica no MP).
exports.saveCard = onRequest(
  { region: "southamerica-east1", secrets: [MP_SECRET], cors: true },
  async (req, res) => {
    if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

    const uid = await verifyToken(req, res);
    if (!uid) return;

    const { token, email } = req.body;
    if (!token || !email) return res.status(400).json({ error: "Dados incompletos" });

    const MP_ACCESS_TOKEN = MP_SECRET.value();
    const headers = {
      Authorization: `Bearer ${MP_ACCESS_TOKEN}`,
      "Content-Type": "application/json",
    };

    try {
      // 1. Usa o customerId já salvo, ou busca/cria por e-mail
      const userRef = admin.firestore().collection("users").doc(uid);
      let customerId = (await userRef.get()).data()?.mpCustomerId;

      if (!customerId) {
        const search = await axios.get(
          `https://api.mercadopago.com/v1/customers/search?email=${encodeURIComponent(email)}`,
          { headers }
        );
        if (search.data.results?.length > 0) {
          customerId = search.data.results[0].id;
        } else {
          const created = await axios.post(
            "https://api.mercadopago.com/v1/customers",
            { email },
            { headers }
          );
          customerId = created.data.id;
        }
        await userRef.update({ mpCustomerId: customerId });
      }

      // 2. Anexa o cartão ao customer
      const cardRes = await axios.post(
        `https://api.mercadopago.com/v1/customers/${customerId}/cards`,
        { token },
        { headers }
      );
      const card = cardRes.data;

      return res.json({
        result: {
          customerId,
          cardId: String(card.id),
          lastFour: card.last_four_digits || "",
          paymentMethodId: card.payment_method?.id || "",
          expiry: `${String(card.expiration_month).padStart(2, "0")}/${String(card.expiration_year).slice(-2)}`,
          holderName: card.cardholder?.name || "",
        },
      });
    } catch (error) {
      const mpError = error.response?.data;
      console.error("saveCard Error:", JSON.stringify(mpError));
      return res.status(500).json({ error: mpError?.message || "Erro ao salvar cartão" });
    }
  }
);

// ─── Conceder papel de admin (custom claim) ───────────────────────────────────
// Só concede ao ADMIN_EMAIL (constante acima). O painel web chama no primeiro
// login; a claim viaja no token e é verificada pelas regras do Firestore.
exports.grantAdmin = onRequest(
  { region: "southamerica-east1", cors: true },
  async (req, res) => {
    if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

    const uid = await verifyToken(req, res);
    if (!uid) return;

    try {
      const user = await admin.auth().getUser(uid);
      if (user.email !== ADMIN_EMAIL) {
        return res.status(403).json({ error: "Acesso restrito" });
      }
      if (user.customClaims?.admin === true) {
        return res.json({ result: { admin: true, refreshed: false } });
      }
      await admin.auth().setCustomUserClaims(uid, { admin: true });
      return res.json({ result: { admin: true, refreshed: true } });
    } catch (e) {
      console.error("grantAdmin error:", e.message);
      return res.status(500).json({ error: "Erro ao conceder acesso" });
    }
  }
);

// ─── Rede de segurança: confirmado e nunca pago ───────────────────────────────
// Desde 2026-09-08 o tutor paga já ao solicitar (createPayment/createPixPayment
// logo após criar o documento) — o vet só é notificado depois do pagamento
// aprovado, então "confirmado sem pagar" não deveria mais existir no fluxo
// normal. MAS: usuários com o app Android antigo (fluxo velho: vet confirma →
// tutor paga depois) ainda podem gerar esse estado enquanto não atualizarem —
// e sem isso o horário fica preso pro profissional pra sempre. Roda a cada 30
// min, bem mais tolerante que a lógica antiga (24h em vez de 12h) já que hoje
// é só rede de segurança, não o caminho esperado.
const PAYMENT_DEADLINE_HOURS = 24;

exports.cancelUnpaid = onSchedule(
  { schedule: "*/30 * * * *", timeZone: "America/Sao_Paulo", region: "southamerica-east1" },
  async () => {
    const db = admin.firestore();
    const now = new Date();

    const snap = await db.collection("appointments")
      .where("status", "==", "confirmed").get();

    let cancelled = 0;
    for (const doc of snap.docs) {
      const d = doc.data();
      if (d.paymentStatus === "approved") continue; // pago: nada a fazer

      const ref = d.confirmedAt?.toDate?.() || d.createdAt?.toDate?.();
      const deadlineExpired = ref &&
        (now - ref) > PAYMENT_DEADLINE_HOURS * 60 * 60 * 1000;

      const apptDateTime = parseApptDateTime(d.date, d.time);
      const apptStarted = apptDateTime ? apptDateTime <= now : false;

      if (!deadlineExpired && !apptStarted) continue;

      await doc.ref.update({
        status: "cancelled",
        cancelReason: "payment_timeout",
        cancelledBy: "sistema",
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      cancelled++;

      const pet = petLabel(d, "seu pet");
      const when = `${d.date || ""} às ${d.time || ""}`;
      const notify = (uid, title, body) => uid
        ? db.collection("notifications").doc(uid).collection("pending").add({
            title, body, read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          })
        : Promise.resolve();

      await Promise.all([
        notify(d.tutorId,
          "⏰ Consulta cancelada",
          `A consulta de ${pet} (${when}) foi cancelada porque o pagamento não foi realizado no prazo. Você pode agendar novamente quando quiser.`),
        notify(d.vetId,
          "⏰ Horário liberado",
          `A consulta de ${pet} (${when}) foi cancelada por falta de pagamento do tutor. O horário voltou a ficar disponível na sua agenda.`),
      ]);
    }

    console.log(`cancelUnpaid: ${cancelled} consulta(s) cancelada(s) (rede de segurança).`);
  }
);

// ─── Verificação de cadastro (pré-registro, sem auth) ────────────────────────
// O app do tutor checa CPF/e-mail duplicados ANTES de criar a conta — sem
// usuário autenticado as regras bloqueiam a consulta direta, então a checagem
// vive aqui (Admin SDK). Retorna apenas booleanos (não vaza dados).
exports.checkRegistration = onRequest(
  { region: "southamerica-east1", cors: true },
  async (req, res) => {
    if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

    const { cpf, email } = req.body || {};
    const db = admin.firestore();

    try {
      let cpfExists = false;
      let emailExists = false;

      if (cpf) {
        const snap = await db.collection("users")
          .where("cpf", "==", String(cpf)).limit(1).get();
        cpfExists = !snap.empty;
      }
      if (email) {
        const snap = await db.collection("users")
          .where("email", "==", String(email).toLowerCase()).limit(1).get();
        emailExists = !snap.empty;
      }

      return res.json({ result: { cpfExists, emailExists } });
    } catch (e) {
      console.error("checkRegistration error:", e.message);
      return res.status(500).json({ error: "Erro ao verificar cadastro" });
    }
  }
);

// ─── Histórico de status (funil de conversão) ─────────────────────────────────
// Regra de ouro: SÓ este arquivo escreve `historico_status`. Os apps gravam
// apenas campos escalares normais (viewedAt, confirmedAt, completedAt,
// rejectedAt...) e a function `appointmentHistorian` abaixo traduz cada
// transição real em um evento do funil.
//
// Por quê centralizado em vez de cada app escrever sua própria entrada:
// Firestore não aceita FieldValue.serverTimestamp() dentro de um array (nem
// em arrayUnion), então se os apps escrevessem o histórico o timestamp viria
// do relógio do celular. Aqui o timestamp vem do servidor (copiado dos
// campos escalares, que sim usam serverTimestamp) — preciso e sem depender
// de nenhum app estar atualizado.

const HIST_FIELD = "historico_status";

function histEntry(status, origem, profissionalId, when, motivo) {
  return {
    status,
    timestamp: when || admin.firestore.Timestamp.now(),
    origem,
    profissional_id: profissionalId || null,
    ...(motivo ? { motivo } : {}),
  };
}

// Append idempotente: cada status aparece no máximo uma vez por agendamento.
// (Triggers do Firestore podem reexecutar; a transação evita evento duplicado.)
async function logEvent(ref, status, origem, profissionalId, when, motivo, extra = {}) {
  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return;
    const d = snap.data() || {};
    const list = Array.isArray(d[HIST_FIELD]) ? d[HIST_FIELD] : [];
    if (list.some((e) => e && e.status === status)) return; // já registrado
    tx.update(ref, {
      [HIST_FIELD]: [...list, histEntry(status, origem, profissionalId, when, motivo)],
      ...extra,
    });
  });
}

// ─── Pagamento antecipado do portal web: reembolso + e-mail ──────────────────
// O portal (agendar.vetvem.com.br) cobra o PIX antes do vet confirmar (o app
// cobra só depois — ver cancelUnpaid). Se o vet não confirmar (recusa ou
// timeout), quem pagou pelo portal precisa ser reembolsado automaticamente e
// avisado por e-mail (não tem push — não instalou o app). Escopo deliberado:
// só agendamentos com bookingOrigin === 'portal_web'; não mexe no fluxo dos
// apps nem no cancelamento manual (cancelled) por ora.

async function refundPayment(paymentId, mpAccessToken) {
  await axios.post(
    `https://api.mercadopago.com/v1/payments/${paymentId}/refunds`,
    {},
    {
      headers: {
        Authorization: `Bearer ${mpAccessToken}`,
        "X-Idempotency-Key": `refund-${paymentId}`,
      },
    }
  );
}

// Domínio mail.vetvem.com.br verificado no Resend (DKIM + SPF em
// send.mail.vetvem.com.br) — entrega pra qualquer destinatário.
async function sendEmail(resendApiKey, to, subject, html) {
  await axios.post(
    "https://api.resend.com/emails",
    { from: "VetVem <agendamentos@mail.vetvem.com.br>", to: [to], subject, html },
    { headers: { Authorization: `Bearer ${resendApiKey}` } }
  );
}

// Orientações do profissional (ex.: jejum) cadastradas no serviço: ao CONFIRMAR,
// vão numa notificação separada ao tutor e ficam guardadas no pedido (detalhe da
// consulta). Retorna o texto (para o e-mail do portal) ou "".
async function sendInstructions(ref, appt) {
  if (appt.instructionsSentAt) return appt.instructionsText || "";
  try {
    if (!appt.vetId || !appt.serviceName) return "";
    const vet = (await admin.firestore().collection("users").doc(appt.vetId).get()).data() || {};
    const name = String(appt.serviceName).trim();
    const svc = (vet.services || []).find((x) => String((x && x.name) || "").trim() === name);
    const text = String((svc && svc.instructions) || "").trim().slice(0, 240);
    if (!text) return "";
    await ref.update({
      instructionsText: text,
      instructionsSentAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    if (appt.tutorId) {
      await admin.firestore().collection("notifications").doc(appt.tutorId).collection("pending").add({
        title: "📋 Orientações para a consulta",
        body: text,
        tipo: "orientacoes",
        appointmentId: ref.id,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    return text;
  } catch (e) {
    console.error("sendInstructions:", e.message);
    return "";
  }
}

function escapeHtml(t) {
  return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

async function onPortalConfirmed(after, resendKey, instructions) {
  if (after.bookingOrigin !== "portal_web" || !after.email) return;
  try {
    await sendEmail(
      resendKey,
      after.email,
      "Seu agendamento VetVem foi confirmado! 🐾",
      `<p>Olá${after.tutorName ? ", " + after.tutorName : ""}!</p>
       <p><strong>${after.vetName || "O profissional"}</strong> confirmou o atendimento ` +
        `para <strong>${petLabel(after, "seu pet")}</strong> em ${after.date} às ${after.time}.</p>
       <p>Endereço: ${after.address || ""}</p>` +
        (instructions
          ? `<p><strong>Orientações do profissional:</strong><br>${escapeHtml(instructions)}</p>`
          : "")
    );
  } catch (e) {
    console.error("onPortalConfirmed email error:", e.response?.data || e.message);
  }
}

// Recusa ou expiração de uma solicitação — cuida do estorno (agora vale para
// QUALQUER origem: apps e portal_web, já que os apps também cobram na hora de
// solicitar desde 2026-09-08) e do aviso ao cliente (push nos apps, e-mail no
// portal_web, que não tem app instalado).
async function handleRejectedPayment(ref, after, mpToken, resendKey) {
  let refunded = false;
  if (after.paymentStatus === "approved" && after.paymentId) {
    try {
      await refundPayment(after.paymentId, mpToken);
      await ref.update({
        paymentStatus: "refunded",
        refundedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      refunded = true;
    } catch (e) {
      const refundError = e.response?.data || e.message;
      console.error("handleRejectedPayment refund error:", refundError);
      // Estorno automático falhou: avisa o admin por e-mail, dinheiro real
      // não pode ficar "preso" sem ninguém saber.
      try {
        await sendEmail(
          resendKey,
          ADMIN_EMAIL,
          `⚠️ Reembolso automático falhou — ${ref.id}`,
          `<p>Falha ao estornar paymentId ${after.paymentId} (agendamento ${ref.id}).</p>
           <p>Erro: ${JSON.stringify(refundError)}</p>
           <p>Estornar manualmente no painel do Mercado Pago.</p>`
        );
      } catch (e2) {
        console.error("handleRejectedPayment admin alert error:", e2.response?.data || e2.message);
      }
    }
  }

  // Apps (tutorId presente): push avisando do estorno. A recusa em si já é
  // avisada na hora pelo próprio app (rejectAppointment) ou pelo timeout
  // (expireUnanswered) — este push cobre só a parte nova, o dinheiro de volta.
  if (after.tutorId && refunded) {
    try {
      await admin.firestore()
        .collection("notifications").doc(after.tutorId)
        .collection("pending").add({
          title: "💸 Valor estornado",
          body: `O valor pago pela consulta de ${petLabel(after, "seu pet")} foi estornado. ` +
            (after.paymentMethod === "pix"
              ? "Já deve aparecer na sua conta em instantes."
              : "Pode levar alguns dias para aparecer na fatura do cartão."),
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    } catch (e) {
      console.error("handleRejectedPayment push error:", e.message);
    }
  }

  // Portal web: não tem app instalado, avisa por e-mail.
  if (after.bookingOrigin !== "portal_web" || !after.email) return;
  try {
    await sendEmail(
      resendKey,
      after.email,
      "Seu agendamento VetVem não pôde ser confirmado",
      `<p>Olá${after.tutorName ? ", " + after.tutorName : ""}!</p>
       ${after.rejectReason === "relocation_declined"
         ? "<p>Conforme você pediu, cancelamos a consulta.</p>"
         : `<p>Infelizmente <strong>${after.vetName || "o profissional"}</strong> não pôde confirmar o atendimento agendado.</p>`}
       ${refunded ? "<p>O valor pago via PIX já foi estornado e deve cair na sua conta em instantes.</p>" : ""}
       <p>Você pode <a href="https://agendar.vetvem.com.br">voltar ao site</a> e escolher outro profissional.</p>
       <p>Ou baixe o app VetVem e tenha acesso a mais veterinários, acompanhamento em tempo real e pagamento direto pelo app:
       <a href="https://play.google.com/store/apps/details?id=com.vetvem.vetvem">baixar o app</a>.</p>`
    );
  } catch (e) {
    console.error("handleRejectedPayment email error:", e.response?.data || e.message);
  }
}

exports.appointmentHistorian = onDocumentWritten(
  {
    document: "appointments/{appointmentId}",
    region: "southamerica-east1",
    secrets: [MP_SECRET, RESEND_SECRET, ORS_SECRET, AWESOME_SECRET],
  },
  async (event) => {
    const before = event.data?.before?.exists ? event.data.before.data() : null;
    const after  = event.data?.after?.exists  ? event.data.after.data()  : null;
    if (!after) return;                       // documento apagado
    const ref = event.data.after.ref;
    const vetId = after.vetId || null;

    // Criação → solicitado
    if (!before) {
      const origem = after.bookingOrigin === "portal_web" ? "portal_web" : "app_tutor";
      return logEvent(ref, "solicitado", origem, vetId, after.createdAt || null);
    }

    const statusChanged = before.status !== after.status;
    const viewedNow = !before.viewedAt && !!after.viewedAt;
    // Guarda anti-loop: nossa própria escrita (só historico_status) cai aqui e sai.
    if (!statusChanged && !viewedNow) return;

    if (viewedNow) {
      await logEvent(ref, "visualizado", "app_pro", vetId, after.viewedAt || null);
    }
    if (!statusChanged) return;

    switch (after.status) {
      case "confirmed": {
        await logEvent(ref, "confirmado", "app_pro", vetId, after.confirmedAt || null);
        // Pedido realocado: o novo profissional aceitou — devolve a diferença de preço.
        if (after.relocationStatus === "awaiting_vet") {
          await settleRelocation(ref, after, { mpToken: MP_SECRET.value(), resendKey: RESEND_SECRET.value() });
        }
        const instructions = await sendInstructions(ref, after);
        return onPortalConfirmed(after, RESEND_SECRET.value(), instructions);
      }

      case "rejected": {
        const rr = after.rejectReason;
        const reason = rr === "no_response" ? "ignorado_timeout"
          : rr === "tutor_no_option" ? "proposta_recusada_tutor"
          : rr === "proposal_expired" ? "proposta_expirada"
          : rr === "relocation_declined" ? "realocacao_recusada_tutor"
          : rr === "relocation_expired" ? "realocacao_expirada"
          : "recusado";
        const origem = rr === "no_response" || rr === "proposal_expired" || rr === "relocation_expired" ? "cloud_function"
          : rr === "tutor_no_option" || rr === "relocation_declined" ? "app_tutor" : "app_pro";
        await logEvent(ref, reason, origem, vetId, after.rejectedAt || null, after.rejectReason || null);
        // Recusa na mão pelo profissional (ou sem resposta ainda não tratada): antes de
        // estornar, oferece outros profissionais ao tutor (se o app dele suporta).
        if ((!rr || rr === "no_response") && !after.relocationAttempted) {
          const started = await startRelocation(ref, after, { resendKey: RESEND_SECRET.value() });
          if (started) return;
        }
        return handleRejectedPayment(ref, after, MP_SECRET.value(), RESEND_SECRET.value());
      }

      case "completed":
        // Backfill: versões antigas do app Pro podem não gravar completedAt.
        return logEvent(ref, "concluido", "app_pro", vetId,
          after.completedAt || null, null,
          after.completedAt ? {} :
            { completedAt: admin.firestore.FieldValue.serverTimestamp() });

      case "cancelled": {
        const by = after.cancelledBy || "sistema";
        const evt = by === "tutor" ? "cancelado_tutor"
                  : by === "profissional" ? "cancelado_profissional"
                  : "cancelado_sistema";
        const origem = by === "tutor" ? "app_tutor"
                     : by === "profissional" ? "app_pro" : "cloud_function";
        return logEvent(ref, evt, origem, vetId,
                        after.cancelledAt || null, after.cancelReason || null);
      }
    }
  }
);

// ─── Expiração de solicitação sem resposta do profissional ───────────────────
// Roda a cada 5 min. Uma solicitação em pending_confirmation vira "rejected"
// quando: (a) passou 2h desde a criação (tempo de sobra pro profissional
// confirmar depois de já ter recebido o pagamento), ou (b) chegou a hora da
// consulta sem resposta. Reaproveita o status "rejected" (os dois apps já
// sabem exibir esse valor — nenhum filtro/UI existente quebra); o evento
// distinto do funil (ignorado_timeout) fica só no historico_status, via
// rejectReason.

const RESPONSE_DEADLINE_MINUTES = 120;

exports.expireUnanswered = onSchedule(
  { schedule: "*/5 * * * *", timeZone: "America/Sao_Paulo", region: "southamerica-east1", secrets: [RESEND_SECRET, ORS_SECRET, AWESOME_SECRET] },
  async () => {
    const db = admin.firestore();
    const now = new Date();

    const snap = await db.collection("appointments")
      .where("status", "==", "pending_confirmation").get();

    let expired = 0;
    for (const doc of snap.docs) {
      const d = doc.data();

      // Profissional já sugeriu outros horários: o prazo agora é do TUTOR
      // (expireProposals, em horarios.js) — não expirar por "sem resposta".
      if (d.proposalStatus === "awaiting_tutor") continue;
      // Tutor escolhendo outro profissional (realocação): o prazo é dele (expireRelocations).
      if (d.relocationStatus === "awaiting_tutor") continue;

      // O prazo do profissional conta a partir do pagamento aprovado (o vet só
      // é avisado nesse momento); sem pagamento, conta da criação.
      const created = d.createdAt?.toDate?.();
      const paidAt = d.paymentStatus === "approved"
        ? (d.paymentUpdatedAt?.toDate?.() || created)
        : null;
      const deadlineStart = paidAt || created;
      // Pedido realocado: o novo profissional tem prazo próprio (responseDeadline, em ms).
      const deadlineExpired = d.responseDeadline
        ? Number(d.responseDeadline) <= now.getTime()
        : deadlineStart && (now - deadlineStart) > RESPONSE_DEADLINE_MINUTES * 60 * 1000;

      const apptDateTime = parseApptDateTime(d.date, d.time);
      const apptStarted = apptDateTime ? apptDateTime <= now : false;

      if (!deadlineExpired && !apptStarted) continue;

      // Antes de encerrar, oferece outros profissionais ao tutor (se possível).
      const relocated = await startRelocation(doc.ref, { ...d, rejectReason: "no_response" },
        { resendKey: RESEND_SECRET.value() });
      if (relocated) continue;

      await doc.ref.update({
        status: "rejected",
        rejectReason: "no_response",
        rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
        relocationAttempted: true,
      });
      expired++;

      // Se nunca foi pago, o vet nunca chegou a ser notificado (só avisamos
      // o vet depois do pagamento aprovado) — não faz sentido dizer "não
      // respondeu" pra quem nunca viu a solicitação, nem avisar o tutor de
      // algo que ele mesmo deixou de fazer (não pagar). Silencioso: só libera
      // o horário. O reembolso (quando pago) é tratado pelo appointmentHistorian.
      if (d.paymentStatus !== "approved") continue;

      const pet = petLabel(d, "seu pet");
      const when = `${d.date || ""} às ${d.time || ""}`;
      const notify = (uid, title, body, extra = {}) => uid
        ? db.collection("notifications").doc(uid).collection("pending").add({
            title, body, read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            tipo: "consulta_expirada", ...extra,
          })
        : Promise.resolve();

      await Promise.all([
        notify(d.tutorId, "⏰ Solicitação sem resposta",
          `${d.vetName || "O profissional"} não respondeu à solicitação para ${pet} (${when}) dentro do prazo. O valor pago será estornado.`),
        notify(d.vetId, "⏰ Solicitação expirada",
          `A solicitação de ${pet} (${when}) expirou por falta de resposta e foi recusada automaticamente.`),
      ]);
    }

    console.log(`expireUnanswered: ${expired} solicitação(ões) expirada(s).`);
  }
);

// ─── Cancelamento manual pelo painel admin ────────────────────────────────────
// Cobre casos que exigem intervenção humana (ex.: agendamento preso por bug,
// pedido do usuário via suporte). Cancela, estorna se já pago e notifica as
// duas partes — a mesma lógica que os cancelamentos automáticos já usam.
exports.adminCancelAppointment = onRequest(
  { region: "southamerica-east1", secrets: [MP_SECRET], cors: true },
  async (req, res) => {
    if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

    const adminUid = await verifyAdmin(req, res);
    if (!adminUid) return;

    const { appointmentId } = req.body || {};
    if (!appointmentId) {
      return res.status(400).json({ error: "appointmentId é obrigatório" });
    }

    const db = admin.firestore();
    const ref = db.collection("appointments").doc(appointmentId);
    const snap = await ref.get();
    if (!snap.exists) {
      return res.status(404).json({ error: "Agendamento não encontrado" });
    }
    const d = snap.data();
    if (["cancelled", "rejected", "completed"].includes(d.status)) {
      return res.status(400).json({ error: `Agendamento já está com status "${d.status}"` });
    }

    try {
      await ref.update({
        status: "cancelled",
        cancelReason: "admin_manual",
        cancelledBy: "sistema",
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      let refunded = false;
      if (d.paymentStatus === "approved" && d.paymentId) {
        try {
          await refundPayment(d.paymentId, MP_SECRET.value());
          await ref.update({
            paymentStatus: "refunded",
            refundedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          refunded = true;
        } catch (e) {
          console.error("adminCancelAppointment refund error:", e.response?.data || e.message);
        }
      }

      const pet = petLabel(d, "um pet");
      const notify = (uid, title, body) => uid
        ? db.collection("notifications").doc(uid).collection("pending").add({
            title, body, read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          })
        : Promise.resolve();

      await Promise.all([
        notify(d.tutorId, "Consulta cancelada",
          `A consulta de ${pet} foi cancelada pela equipe VetVem.` +
            (refunded ? " O valor pago foi estornado." : "")),
        notify(d.vetId, "Consulta cancelada",
          `A consulta de ${pet} foi cancelada pela equipe VetVem. O horário voltou a ficar disponível.`),
      ]);

      return res.json({ result: { ok: true, refunded } });
    } catch (e) {
      console.error("adminCancelAppointment error:", e.message);
      return res.status(500).json({ error: "Erro ao cancelar agendamento" });
    }
  }
);

// ─── Taxonomias editáveis: especialidades e espécies ──────────────────────────
// Antes hardcoded em 3 lugares (register_controller.dart no Pro,
// vets_controller.dart e home_view.dart no tutor) — cada categoria nova
// exigia código + release nos dois apps. Agora vivem em config/specialties e
// config/species, editáveis pelo painel admin, lidas pelos apps em runtime.
// Ícones são nomes (string) resolvidos por um mapa no cliente — Firestore não
// serializa IconData.

const DEFAULT_SPECIALTIES = [
  { label: "Consulta", specialty: "Clínica Geral", icon: "medical_services_outlined",
    description: "Avaliação clínica completa no conforto da sua casa. O veterinário examina seu pet, orienta sobre saúde preventiva, vacinas e exames, sem estresse do transporte." },
  { label: "Banho & Tosa", specialty: "Banho & Tosa", icon: "content_cut",
    description: "Banho, escovação, tosa higiênica ou completa feitos por profissional qualificado na sua porta. Seu pet limpo e cheiroso sem sair de casa." },
  { label: "Fisioterapia", specialty: "Fisioterapia", icon: "self_improvement_outlined",
    description: "Reabilitação e fisioterapia animal para pets em recuperação de cirurgias, fraturas ou doenças degenerativas. Sessões personalizadas no ambiente familiar do animal." },
  { label: "Adestramento", specialty: "Adestramento", icon: "psychology_outlined",
    description: "Adestramento e educação comportamental com reforço positivo. Ideal para filhotes, pets com comportamentos indesejados ou que precisam de socialização." },
  { label: "Vacinação", specialty: "Vacinação", icon: "vaccines_outlined",
    description: "Vacinação em dia sem filas e sem estresse. O profissional aplica as vacinas necessárias em casa, com toda a segurança e o registro no carteirinha do pet." },
  { label: "Acupuntura", specialty: "Acupuntura", icon: "spa_outlined",
    description: "Acupuntura veterinária para alívio de dor crônica, tratamento de doenças neurológicas, artrite e bem-estar geral. Técnica milenar aplicada por especialista certificado." },
];

const DEFAULT_SPECIES = [
  { key: "dog", emoji: "🐶", label: "Cão" },
  { key: "cat", emoji: "🐱", label: "Gato" },
  { key: "bird", emoji: "🐦", label: "Ave" },
  { key: "rabbit", emoji: "🐰", label: "Coelho" },
  { key: "rodent", emoji: "🐹", label: "Roedor" },
  { key: "reptile", emoji: "🦎", label: "Réptil" },
  { key: "fish", emoji: "🐟", label: "Peixe" },
  { key: "exotic", emoji: "🦜", label: "Exótico" },
];

exports.seedTaxonomies = onRequest(
  { region: "southamerica-east1", cors: true },
  async (req, res) => {
    const db = admin.firestore();
    const result = {};

    const specialtiesRef = db.collection("config").doc("specialties");
    if (!(await specialtiesRef.get()).exists) {
      await specialtiesRef.set({ items: DEFAULT_SPECIALTIES });
      result.specialties = "seeded";
    } else {
      result.specialties = "already exists, skipped";
    }

    const speciesRef = db.collection("config").doc("species");
    if (!(await speciesRef.get()).exists) {
      await speciesRef.set({ items: DEFAULT_SPECIES });
      result.species = "seeded";
    } else {
      result.species = "already exists, skipped";
    }

    return res.json({ result });
  }
);

// ─── Encerrar conta (LGPD + Apple Guideline 5.1.1(v)) ─────────────────────────
// Exclusão self-service dentro do app (tutor e Pro). Não é hard delete puro:
// agendamentos concluídos/pagos ficam no Firestore por causa de histórico
// financeiro (repasses, fiscal, disputa de pagamento) — só a PII é apagada
// (anonimização). O que É removido de fato: a conta no Firebase Auth (login
// nunca mais funciona), o customer no cofre do Mercado Pago (cartões
// salvos) e a subcoleção de documentos (RG/CNH/CRMV). Agendamentos futuros
// ainda em aberto são cancelados e a outra parte é avisada + reembolsada
// (mesma lógica do handleRejectedPayment).
exports.deleteAccount = onRequest(
  { region: "southamerica-east1", secrets: [MP_SECRET], cors: true },
  async (req, res) => {
    if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

    const uid = await verifyToken(req, res);
    if (!uid) return;

    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
      return res.status(404).json({ error: "Usuário não encontrado" });
    }
    const user = userSnap.data();
    const MP_ACCESS_TOKEN = MP_SECRET.value();

    try {
      // 1) Cancela agendamentos em aberto (como tutor OU como vet) e
      // reembolsa/avisa a outra parte.
      const openStatuses = ["pending_confirmation", "confirmed"];
      const [asTutor, asVet] = await Promise.all([
        db.collection("appointments")
          .where("tutorId", "==", uid).where("status", "in", openStatuses).get(),
        db.collection("appointments")
          .where("vetId", "==", uid).where("status", "in", openStatuses).get(),
      ]);

      for (const doc of [...asTutor.docs, ...asVet.docs]) {
        const d = doc.data();
        const isTutor = d.tutorId === uid;

        await doc.ref.update({
          status: "cancelled",
          cancelReason: "account_deleted",
          cancelledBy: isTutor ? "tutor" : "profissional",
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        let refunded = false;
        if (d.paymentStatus === "approved" && d.paymentId) {
          try {
            await refundPayment(d.paymentId, MP_ACCESS_TOKEN);
            await doc.ref.update({
              paymentStatus: "refunded",
              refundedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            refunded = true;
          } catch (e) {
            console.error("deleteAccount refund error:", e.response?.data || e.message);
          }
        }

        const otherUid = isTutor ? d.vetId : d.tutorId;
        if (otherUid) {
          await db.collection("notifications").doc(otherUid).collection("pending").add({
            title: "Consulta cancelada",
            body: `A consulta de ${petLabel(d, "um pet")} foi cancelada porque ` +
              `${isTutor ? "o tutor" : "o profissional"} encerrou a conta no VetVem.` +
              (refunded ? " O valor pago foi estornado." : ""),
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      // 2) Remove o customer do cofre do Mercado Pago (leva os cartões salvos).
      if (user.mpCustomerId) {
        try {
          await axios.delete(
            `https://api.mercadopago.com/v1/customers/${user.mpCustomerId}`,
            { headers: { Authorization: `Bearer ${MP_ACCESS_TOKEN}` } }
          );
        } catch (e) {
          console.error("deleteAccount mpCustomer error:", e.response?.data || e.message);
        }
      }

      // 3) Apaga a subcoleção de documentos (RG/CNH/CRMV) do profissional.
      const docsSnap = await userRef.collection("documents").get();
      if (!docsSnap.empty) {
        const batch = db.batch();
        docsSnap.docs.forEach((d) => batch.delete(d.ref));
        await batch.commit();
      }

      // 4) Anonimiza PII no doc (mantido por causa do histórico financeiro
      // referenciado em appointments/payouts) e marca como excluído/bloqueado.
      await userRef.update({
        name: "Usuário removido",
        email: admin.firestore.FieldValue.delete(),
        phone: admin.firestore.FieldValue.delete(),
        photoBase64: admin.firestore.FieldValue.delete(),
        cpf: admin.firestore.FieldValue.delete(),
        crmv: admin.firestore.FieldValue.delete(),
        pixKeys: admin.firestore.FieldValue.delete(),
        addresses: admin.firestore.FieldValue.delete(),
        fcmToken: admin.firestore.FieldValue.delete(),
        mpCustomerId: admin.firestore.FieldValue.delete(),
        blocked: true,
        accountStatus: "deleted",
        isAvailable: false,
        deletedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 5) Remove a conta do Firebase Authentication — login nunca mais funciona.
      await admin.auth().deleteUser(uid);

      return res.json({ result: { ok: true } });
    } catch (e) {
      console.error("deleteAccount error:", e.message);
      return res.status(500).json({ error: "Erro ao encerrar conta. Tente novamente." });
    }
  }
);

// ─── Segurança da chave PIX ───────────────────────────────────────────────────
// Quando o profissional adiciona/troca/remove chave PIX: grava pixChangedAt
// (campo protegido nas rules; só o servidor escreve), guarda histórico, avisa
// por push (via notifications -> sendPush) e por e-mail. O dailyPayouts retém
// os repasses por PIX_HOLD_HOURS depois dessa data.
exports.pixKeyWatcher = onDocumentUpdated(
  { document: "users/{uid}", region: "southamerica-east1", secrets: [RESEND_SECRET] },
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    if (after.role !== "professional") return;
    if (JSON.stringify(after.pixKeys || []) === JSON.stringify(before.pixKeys || [])) return;

    const uid = event.params.uid;
    const db = admin.firestore();
    const mask = (list) => (list || []).map((k) => `${k.type}: ${String(k.key || "").slice(0, 3)}***`);

    await db.doc(`users/${uid}`).update({ pixChangedAt: admin.firestore.FieldValue.serverTimestamp() });
    await db.collection(`users/${uid}/pixHistory`).add({
      at: admin.firestore.FieldValue.serverTimestamp(),
      from: mask(before.pixKeys),
      to: mask(after.pixKeys),
    });
    await db.collection("notifications").doc(uid).collection("pending").add({
      title: "Sua chave PIX foi alterada",
      body: "Não foi você? Fale com a gente agora. Por segurança, o próximo repasse pode levar até 48h a mais.",
      tipo: "pix_alterada",
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    try {
      const user = await admin.auth().getUser(uid);
      if (user.email) {
        await sendEmail(
          RESEND_SECRET.value(),
          user.email,
          "Sua chave PIX no VetVem foi alterada",
          `<p>Olá${after.name ? ", " + after.name : ""}!</p>
           <p>A chave PIX da sua conta VetVem Pro foi alterada agora.</p>
           <p><strong>Não foi você?</strong> Responda este e-mail imediatamente e troque sua senha.</p>
           <p>Por segurança, o próximo repasse pode levar até ${PIX_HOLD_HOURS}h a mais.</p>`
        );
      }
    } catch (e) {
      console.error("pixKeyWatcher email error:", e.response?.data || e.message);
    }
  }
);

// Espelho público dos profissionais (professionals_public) — vitrine sem dados privados
Object.assign(exports, require("./professionals_public"));

// E-mail de redefinição de senha com a marca VetVem
Object.assign(exports, require("./password_reset"));

// Sincronização do diretório de profissionais do site (vetvem.com.br/profissionais/)
Object.assign(exports, require("./site_sync"));

// Blog automático do site (vetvem.com.br/blog/) — ver blog_auto.js
Object.assign(exports, require("./blog_auto"));

// Sugestão de novos horários (profissional -> tutor): proposeNewTimes, respondToProposal, expireProposals
Object.assign(exports, require("./horarios"));

// Realocação de profissional (tutor escolhe outro quando o veterinário recusa/não responde).
Object.assign(exports, require("./realocacao"));
Object.assign(exports, require("./portal_relocation"));
Object.assign(exports, require("./travel"));

// Cadastro rejeitado que reenvia documentos volta para a fila de análise.
Object.assign(exports, require("./account_review"));

// Contatos do agendamento para o painel admin.
Object.assign(exports, require("./admin_contacts"));
