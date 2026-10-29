// Deslocamento por km — endpoints.
//   travelQuote  POST {vetId, cep}  (usuário autenticado) -> valor do deslocamento até aquele CEP
//   geocodeVetOrigin  (trigger em users/{uid}) -> guarda as coordenadas de origem do profissional
//        em vet_origins/{uid} (privado: o endereço/coordenadas nunca vão para o tutor)
// As regras de cálculo ficam em travel_lib.js; o acesso a mapa/cache em travel_core.js.
const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const T = require("./travel_lib");
const core = require("./travel_core");

const { ORS_SECRET, AWESOME_SECRET, orsKey: orsKeyOrNull } = core;

async function authUid(req) {
  const auth = req.headers.authorization || "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : null;
  if (!token) return null;
  try { return (await admin.auth().verifyIdToken(token)).uid; } catch (_) { return null; }
}

const ERRORS = {
  cep_invalido: [400, "CEP inválido."],
  origem_ausente: [409, "Este profissional ainda não configurou o deslocamento."],
  destino_nao_encontrado: [422, "Não encontramos esse CEP. Confira e tente de novo."],
  limite: [429, "Muitas consultas hoje. Tente novamente mais tarde."],
};

exports.travelQuote = onRequest(
  { region: "southamerica-east1", cors: true, secrets: [ORS_SECRET, AWESOME_SECRET] },
  async (req, res) => {
    if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });
    const uid = await authUid(req);
    if (!uid) return res.status(401).json({ error: "Token inválido" });
    const { vetId, cep } = req.body || {};
    if (!vetId || typeof vetId !== "string") return res.status(400).json({ error: "Profissional não informado." });
    try {
      const q = await core.quoteTravel(vetId, cep, { orsKey: orsKeyOrNull(), uid });
      if (!q.ok) {
        const [code, msg] = ERRORS[q.error] || [500, "Erro ao calcular o deslocamento."];
        return res.status(code).json({ error: msg, code: q.error });
      }
      return res.json(q);
    } catch (e) {
      console.error("travelQuote:", e.message);
      return res.status(500).json({ error: "Erro ao calcular o deslocamento." });
    }
  }
);

// Quando o profissional informa/troca o CEP de origem, guarda as coordenadas (privadas).
exports.geocodeVetOrigin = onDocumentWritten(
  { document: "users/{uid}", region: "southamerica-east1", secrets: [ORS_SECRET, AWESOME_SECRET], timeoutSeconds: 60 },
  async (event) => {
    const after = event.data?.after?.exists ? event.data.after.data() : null;
    const before = event.data?.before?.exists ? event.data.before.data() : null;
    if (!after || after.role !== "professional") return;
    if ((before && before.originCep) === after.originCep) return; // sem mudança no CEP
    const uid = event.params.uid;
    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);
    const originRef = db.collection("vet_origins").doc(uid);
    const raw = after.originCep;
    if (raw === undefined || raw === null || String(raw).trim() === "") {
      await originRef.delete();
      await userRef.update({ originGeoStatus: admin.firestore.FieldValue.delete() });
      return;
    }
    const cep = T.normalizeCep(raw);
    if (!cep) {
      await originRef.delete();
      await userRef.update({ originGeoStatus: "invalid" });
      return;
    }
    const p = await core.geocodeCep(cep, orsKeyOrNull());
    if (!p) {
      await originRef.delete();
      await userRef.update({ originGeoStatus: "not_found" });
      return;
    }
    await originRef.set({ lat: p.lat, lng: p.lng, cep, v: 3, at: Date.now() });
    await userRef.update({ originGeoStatus: "ok" });
  }
);
// rev 1793223788
// rev 1793279028
// rev 1793279182
