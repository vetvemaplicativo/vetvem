const { setGlobalOptions } = require("firebase-functions");
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const axios = require("axios");

setGlobalOptions({ maxInstances: 10, region: "southamerica-east1" });

admin.initializeApp();

const MP_SECRET = defineSecret("MP_ACCESS_TOKEN");
const RESEND_SECRET = defineSecret("RESEND_API_KEY");

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

// ─── Criar pagamento com cartão ───────────────────────────────────────────────
exports.createPayment = onRequest(
  { region: "southamerica-east1", secrets: [MP_SECRET], cors: true },
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
      const response = await axios.post(
        "https://api.mercadopago.com/v1/payments",
        {
          transaction_amount: amount,
          token,
          description,
          installments: installments || 1,
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
        paymentAmount: amount,
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
  { region: "southamerica-east1", secrets: [MP_SECRET], cors: true },
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
      const response = await axios.post(
        "https://api.mercadopago.com/v1/payments",
        {
          transaction_amount: amount,
          description,
          payment_method_id: "pix",
          payer: {
            email,
            first_name: firstName || "Cliente",
            last_name: lastName || "VetVem",
            identification: { type: "CPF", number: cpf || "00000000000" },
          },
          external_reference: appointmentId,
          date_of_expiration: new Date(Date.now() + 30 * 60 * 1000).toISOString(),
          notification_url: `https://southamerica-east1-vetvem-18bf4.cloudfunctions.net/mpWebhook`,
        },
        {
          headers: {
            Authorization: `Bearer ${MP_ACCESS_TOKEN}`,
            "Content-Type": "application/json",
            "X-Idempotency-Key": `pix-${appointmentId}`,
          },
        }
      );

      const payment = response.data;
      const pixData = payment.point_of_interaction?.transaction_data;

      await admin.firestore().collection("appointments").doc(appointmentId).update({
        paymentId: String(payment.id),
        paymentStatus: payment.status,
        paymentMethod: "pix",
        paymentAmount: amount,
        paymentDate: admin.firestore.FieldValue.serverTimestamp(),
      });

      return res.json({
        result: {
          status: payment.status,
          paymentId: payment.id,
          pixCopyPaste: pixData?.qr_code,
          pixQrCodeBase64: pixData?.qr_code_base64,
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

            // Corrida: o PIX do portal pode cair depois do vet já ter
            // recusado (appointmentHistorian não reembolsou na hora porque
            // ainda não tinha sido pago). Confere o estado atual e reembolsa.
            if (current && current.status === "rejected") {
              await onPortalNotConfirmed(
                ref,
                { ...current, paymentStatus: "approved", paymentId: String(payment.id) },
                MP_ACCESS_TOKEN,
                RESEND_SECRET.value()
              );
            } else if (
              current &&
              current.bookingOrigin === "portal_web" &&
              current.status === "pending_confirmation" &&
              current.vetId &&
              !current.vetNotifiedAt
            ) {
              // No portal o vet só é avisado depois do PIX confirmado — o app
              // avisa na hora da criação (ver scheduling_controller.dart),
              // mas ali o pedido não existe sem já estar pago.
              await admin
                .firestore()
                .collection("notifications")
                .doc(current.vetId)
                .collection("pending")
                .add({
                  title: "🗓️ Novo agendamento!",
                  body: `${current.tutorName || "Um tutor"} agendou ${current.serviceName || "uma consulta"} para ${current.petName || "o pet"} em ${current.date} às ${current.time}.`,
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

const ADMIN_EMAIL = "ronalddesouzabr@gmail.com"; // conta que recebe o resumo diário

function parseApptDate(s) {
  // "23/06/2026" → Date
  const p = (s || "").split("/");
  if (p.length < 3) return null;
  const d = new Date(`${p[2]}-${p[1].padStart(2, "0")}-${p[0].padStart(2, "0")}T12:00:00-03:00`);
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
    const overrideByVet = {}; // isenção/taxa custom (com prazo opcional)
    for (const vetId of vetIds) {
      const vetDoc = await db.collection("users").doc(vetId).get();
      const d = vetDoc.data() || {};
      const keys = d.pixKeys || [];
      pixByVet[vetId] = keys.length > 0 ? `${keys[0].key} (${keys[0].type})` : "sem chave PIX cadastrada";
      if (d.feeOverride != null) {
        const until = d.feeOverrideUntil;
        const expired = until && until.toDate && until.toDate() < new Date();
        if (!expired) overrideByVet[vetId] = d.feeOverride;
      }
    }

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
        petName: a.petName || "",
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

// ─── Cancelamento automático por falta de pagamento ───────────────────────────
// Roda a cada 30 min. Consulta confirmada e não paga é cancelada quando:
// (a) passaram 12h desde a confirmação, ou (b) o horário da consulta chegou.
// Ambos (tutor e vet) são notificados e o horário volta a ficar livre.

const PAYMENT_DEADLINE_HOURS = 12;

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

      // Prazo 1: 12h após a confirmação (fallback: criação)
      const ref = d.confirmedAt?.toDate?.() || d.createdAt?.toDate?.();
      const deadlineExpired = ref &&
        (now - ref) > PAYMENT_DEADLINE_HOURS * 60 * 60 * 1000;

      // Prazo 2: horário da consulta chegou sem pagamento
      let apptStarted = false;
      const apptDate = parseApptDate(d.date);
      if (apptDate) {
        const [h, m] = (d.time || "23:59").split(":").map(Number);
        apptDate.setHours(h || 23, m || 59, 0, 0);
        apptStarted = apptDate <= now;
      }

      if (!deadlineExpired && !apptStarted) continue;

      await doc.ref.update({
        status: "cancelled",
        cancelReason: "payment_timeout",
        cancelledBy: "sistema",
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      cancelled++;

      const pet = d.petName || "seu pet";
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

    console.log(`cancelUnpaid: ${cancelled} consulta(s) cancelada(s).`);
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

async function onPortalConfirmed(after, resendKey) {
  if (after.bookingOrigin !== "portal_web" || !after.email) return;
  try {
    await sendEmail(
      resendKey,
      after.email,
      "Seu agendamento VetVem foi confirmado! 🐾",
      `<p>Olá${after.tutorName ? ", " + after.tutorName : ""}!</p>
       <p><strong>${after.vetName || "O profissional"}</strong> confirmou o atendimento ` +
        `para <strong>${after.petName || "seu pet"}</strong> em ${after.date} às ${after.time}.</p>
       <p>Endereço: ${after.address || ""}</p>`
    );
  } catch (e) {
    console.error("onPortalConfirmed email error:", e.response?.data || e.message);
  }
}

async function onPortalNotConfirmed(ref, after, mpToken, resendKey) {
  if (after.bookingOrigin !== "portal_web") return;

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
      console.error("onPortalNotConfirmed refund error:", refundError);
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
        console.error("onPortalNotConfirmed admin alert error:", e2.response?.data || e2.message);
      }
    }
  }

  if (!after.email) return;
  try {
    await sendEmail(
      resendKey,
      after.email,
      "Seu agendamento VetVem não pôde ser confirmado",
      `<p>Olá${after.tutorName ? ", " + after.tutorName : ""}!</p>
       <p>Infelizmente <strong>${after.vetName || "o profissional"}</strong> não pôde confirmar o atendimento agendado.</p>
       ${refunded ? "<p>O valor pago via PIX já foi estornado e deve cair na sua conta em instantes.</p>" : ""}
       <p>Você pode <a href="https://agendar.vetvem.com.br">voltar ao site</a> e escolher outro profissional.</p>
       <p>Ou baixe o app VetVem e tenha acesso a mais veterinários, acompanhamento em tempo real e pagamento direto pelo app:
       <a href="https://play.google.com/store/apps/details?id=com.vetvem.vetvem">baixar o app</a>.</p>`
    );
  } catch (e) {
    console.error("onPortalNotConfirmed email error:", e.response?.data || e.message);
  }
}

exports.appointmentHistorian = onDocumentWritten(
  {
    document: "appointments/{appointmentId}",
    region: "southamerica-east1",
    secrets: [MP_SECRET, RESEND_SECRET],
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
      case "confirmed":
        await logEvent(ref, "confirmado", "app_pro", vetId, after.confirmedAt || null);
        return onPortalConfirmed(after, RESEND_SECRET.value());

      case "rejected": {
        const reason = after.rejectReason === "no_response" ? "ignorado_timeout" : "recusado";
        const origem = after.rejectReason === "no_response" ? "cloud_function" : "app_pro";
        await logEvent(ref, reason, origem, vetId, after.rejectedAt || null, after.rejectReason || null);
        return onPortalNotConfirmed(ref, after, MP_SECRET.value(), RESEND_SECRET.value());
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
// quando: (a) passaram 30 min desde a criação, ou (b) chegou a hora da
// consulta sem resposta. Reaproveita o status "rejected" (os dois apps já
// sabem exibir esse valor — nenhum filtro/UI existente quebra); o evento
// distinto do funil (ignorado_timeout) fica só no historico_status, via
// rejectReason.

const RESPONSE_DEADLINE_MINUTES = 30;

exports.expireUnanswered = onSchedule(
  { schedule: "*/5 * * * *", timeZone: "America/Sao_Paulo", region: "southamerica-east1" },
  async () => {
    const db = admin.firestore();
    const now = new Date();

    const snap = await db.collection("appointments")
      .where("status", "==", "pending_confirmation").get();

    let expired = 0;
    for (const doc of snap.docs) {
      const d = doc.data();

      const created = d.createdAt?.toDate?.();
      const deadlineExpired = created &&
        (now - created) > RESPONSE_DEADLINE_MINUTES * 60 * 1000;

      let apptStarted = false;
      const apptDate = parseApptDate(d.date);
      if (apptDate) {
        const [h, m] = (d.time || "23:59").split(":").map(Number);
        apptDate.setHours(h || 23, m || 59, 0, 0);
        apptStarted = apptDate <= now;
      }

      if (!deadlineExpired && !apptStarted) continue;

      await doc.ref.update({
        status: "rejected",
        rejectReason: "no_response",
        rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      expired++;

      const pet = d.petName || "seu pet";
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
          `${d.vetName || "O profissional"} não respondeu à solicitação para ${pet} (${when}) dentro do prazo. Você pode escolher outro profissional.`),
        notify(d.vetId, "⏰ Solicitação expirada",
          `A solicitação de ${pet} (${when}) expirou por falta de resposta e foi recusada automaticamente.`),
      ]);
    }

    console.log(`expireUnanswered: ${expired} solicitação(ões) expirada(s).`);
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
