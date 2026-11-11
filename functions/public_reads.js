// Endpoints de leitura pública (qualquer login válido, inclusive o anônimo do portal).
//   busyTimes   POST {vetId?, vetName?, date: "dd/mm/aaaa"} -> { times: ["09:00", ...] }
//   vetReviews  POST {vetId, vetName?}                       -> { reviews, rating, reviewCount }
// Existem para o Firestore poder negar a leitura ampla de `appointments`.
const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const lib = require("./public_reads_lib");

const OPTS = { region: "southamerica-east1", cors: true };

async function authed(req, res) {
  const h = req.headers.authorization || "";
  const token = h.startsWith("Bearer ") ? h.slice(7) : null;
  if (!token) { res.status(401).json({ error: "Token não fornecido" }); return false; }
  try { await admin.auth().verifyIdToken(token); return true; } catch (_) {
    res.status(401).json({ error: "Token inválido" }); return false;
  }
}

// Pedidos do profissional por id e por nome (pedidos antigos só têm vetName), sem duplicar.
async function vetDocs({ vetId, vetName }) {
  const col = admin.firestore().collection("appointments");
  const seen = new Map();
  if (vetId) for (const d of (await col.where("vetId", "==", vetId).get()).docs) seen.set(d.id, d.data());
  if (vetName) for (const d of (await col.where("vetName", "==", vetName).get()).docs) if (!seen.has(d.id)) seen.set(d.id, d.data());
  return [...seen.values()];
}

exports.busyTimes = onRequest(OPTS, async (req, res) => {
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });
  if (!(await authed(req, res))) return;
  const { vetId, vetName, date } = req.body || {};
  if (!lib.validDate(date)) return res.status(400).json({ error: "date deve ser dd/mm/aaaa" });
  if (!vetId && !vetName) return res.status(400).json({ error: "Informe vetId ou vetName" });
  try {
    const docs = await vetDocs({ vetId: vetId && String(vetId), vetName: vetName && String(vetName) });
    return res.json({ times: lib.pickBusyTimes(docs, date) });
  } catch (e) {
    console.error("busyTimes:", e.message);
    return res.status(500).json({ error: "Erro ao consultar horários" });
  }
});

exports.vetReviews = onRequest(OPTS, async (req, res) => {
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });
  if (!(await authed(req, res))) return;
  const { vetId, vetName } = req.body || {};
  if (!vetId && !vetName) return res.status(400).json({ error: "Informe vetId ou vetName" });
  try {
    const docs = await vetDocs({ vetId: vetId && String(vetId), vetName: vetName && String(vetName) });
    return res.json(lib.pickReviews(docs));
  } catch (e) {
    console.error("vetReviews:", e.message);
    return res.status(500).json({ error: "Erro ao consultar avaliações" });
  }
});

// Nota/contagem/concluídos do profissional recalculados NO SERVIDOR quando uma avaliação entra ou um
// atendimento é concluído (antes o app do tutor recalculava e gravava direto no users/{vet}, o que
// permitia forjar a nota). O espelho professionals_public reage à gravação em users.
exports.syncVetRating = onDocumentUpdated(
  { document: "appointments/{appointmentId}", region: "southamerica-east1" },
  async (event) => {
    const b = event.data && event.data.before && event.data.before.data();
    const a = event.data && event.data.after && event.data.after.data();
    if (!a || !b) return;
    const ratingChanged = b.rating !== a.rating;
    const justCompleted = b.status !== "completed" && a.status === "completed";
    if (!ratingChanged && !justCompleted) return;
    let vetId = a.vetId;
    if (!vetId && a.vetName) {
      const q = await admin.firestore().collection("professionals_public").where("name", "==", a.vetName).limit(1).get();
      if (!q.empty) vetId = q.docs[0].id;
    }
    if (!vetId) return;
    const docs = await vetDocs({ vetId, vetName: a.vetName });
    const agg = lib.aggregateVet(docs);
    await admin.firestore().collection("users").doc(vetId).update(agg);
  }
);
