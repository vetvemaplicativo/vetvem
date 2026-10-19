// Sincroniza profissionais aprovados (Firestore users/{uid}) com o diretório
// do site (vetvem.com.br/profissionais/ — mu-plugin vetvem-veterinarios).
//
// Só trafegam campos PÚBLICOS: nome, CRMV, bio, categorias, espécies, faixa de
// preço, área de atuação (estado/cidades/bairros) e foto. Nunca telefone,
// e-mail, endereço residencial, PIX ou documentos.
//
// Duas vias, para não depender de uma só:
//  - syncProfessionalToSite: em tempo real, a cada mudança relevante no perfil;
//  - syncProfessionalsToSite: reconciliação a cada 6h (pega o que falhou e
//    oculta no site quem deixou de estar aprovado). Também disponível sob
//    demanda em syncProfessionalsNow (protegida pelo mesmo segredo).

const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const axios = require("axios");
const crypto = require("crypto");

const SITE_SECRET = defineSecret("WP_SYNC_SECRET");
const SITE_API = "https://vetvem.com.br/wp-json/vetvem/v1";

// Rótulos iguais aos termos já existentes no site (plural).
const ESPECIES = {
  dog: "Cães", cat: "Gatos", bird: "Aves", rabbit: "Coelhos",
  rodent: "Roedores", reptile: "Répteis", fish: "Peixes", exotic: "Exóticos",
};

const norm = (s) => String(s || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");

function parsePrice(v) {
  const n = parseFloat(String(v ?? "0").replace(",", "."));
  return Number.isFinite(n) ? n : 0;
}

// Mesmos critérios do app do tutor / portal: aprovado (ou 'active' legado) e não bloqueado.
function isPublic(d) {
  return !!d && d.role === "professional" &&
    (d.accountStatus === "approved" || d.accountStatus === "active") &&
    d.blocked !== true;
}

function tipoDe(d) {
  if (String(d.crmv || "").trim()) return "veterinario";
  const cats = (d.categories || []).map(norm);
  if (cats.some((c) => c.includes("banho"))) return "banho-e-tosa";
  if (cats.some((c) => c.includes("adestr"))) return "adestramento";
  return "outros-servicos";
}

function photoOf(d) {
  let b64 = typeof d.photoBase64 === "string" ? d.photoBase64.trim() : "";
  if (!b64) return null;
  b64 = b64.replace(/^data:image\/[a-z+]+;base64,/i, "");
  return { b64, hash: crypto.createHash("sha1").update(b64).digest("hex") };
}

function buildPayload(uid, d, { withPhotoBytes }) {
  const area = d.area_atuacao || {};
  const cidades = (Array.isArray(area.cidades) ? area.cidades : [])
    .map((c) => ({
      nome: String(c.nome || "").trim(),
      toda: c.atende_cidade_toda === true,
      bairros: Array.isArray(c.bairros) ? c.bairros.map(String) : [],
    }))
    .filter((c) => c.nome);
  const photo = photoOf(d);
  return {
    uid,
    active: isPublic(d),
    name: String(d.name || "").trim(),
    crmv: String(d.crmv || "").trim(),
    bio: String(d.bio || "").trim(),
    tipo: tipoDe(d),
    categories: (d.categories || []).map(String),
    species: (d.animalSpecies || []).map((k) => ESPECIES[k] || String(k)),
    estado: String(area.estado || "").trim().toUpperCase(),
    cidades,
    precos: (d.services || []).map((s) => parsePrice(s.price)).filter((p) => p > 0),
    photo: photo ? (withPhotoBytes ? photo : { hash: photo.hash }) : null,
  };
}

async function post(path, body, secret) {
  const r = await axios.post(`${SITE_API}${path}`, body, {
    headers: { "X-VetVem-Secret": secret, "Content-Type": "application/json" },
    timeout: 60000,
    maxBodyLength: Infinity,
    maxContentLength: Infinity,
    validateStatus: () => true,
  });
  return r;
}

// Envia um profissional. No modo reconciliação a foto vai por hash e os bytes
// só seguem se o site pedir (evita reenviar fotos a cada 6h).
async function pushProfessional(uid, d, secret, { reconcile }) {
  const payload = buildPayload(uid, d, { withPhotoBytes: !reconcile });
  let r = await post("/profissional", payload, secret);
  if (r.status === 200 && r.data && r.data.foto_pendente) {
    r = await post("/profissional", buildPayload(uid, d, { withPhotoBytes: true }), secret);
  }
  if (r.status !== 200) {
    console.error(`site_sync: falha ${r.status} para ${uid}:`, JSON.stringify(r.data).slice(0, 300));
  }
  return r;
}

exports.syncProfessionalToSite = onDocumentWritten(
  { document: "users/{uid}", region: "southamerica-east1", secrets: [SITE_SECRET], timeoutSeconds: 120 },
  async (event) => {
    const uid = event.params.uid;
    const before = event.data?.before?.exists ? event.data.before.data() : null;
    const after = event.data?.after?.exists ? event.data.after.data() : null;
    const eraProfissional = before && before.role === "professional";
    const eProfissional = after && after.role === "professional";
    if (!eraProfissional && !eProfissional) return;

    // Documento apagado: oculta no site.
    if (!after) {
      if (!isPublic(before)) return;
      await post("/profissional", { uid, active: false, name: before.name || "", crmv: before.crmv || "" }, SITE_SECRET.value());
      return;
    }

    // Só continua se algo PÚBLICO mudou (avaliações/contadores mudam o tempo todo).
    const a = JSON.stringify(buildPayload(uid, after, { withPhotoBytes: false }));
    const b = before ? JSON.stringify(buildPayload(uid, before, { withPhotoBytes: false })) : null;
    if (a === b) return;
    if (!isPublic(after) && !(before && isPublic(before))) return; // pendente → pendente

    await pushProfessional(uid, after, SITE_SECRET.value(), { reconcile: false });
  }
);

async function reconcileAll(secret) {
  const snap = await admin.firestore().collection("users").where("role", "==", "professional").get();
  const publicUids = [];
  const stats = { total: snap.size, publicos: 0, criados: 0, atualizados: 0, inalterados: 0, ocultados: 0, falhas: 0 };
  for (const doc of snap.docs) {
    const d = doc.data();
    if (!isPublic(d)) {
      // Garante que quem saiu do aprovado também saia do site.
      const r = await post("/profissional", { uid: doc.id, active: false, name: d.name || "", crmv: d.crmv || "" }, secret);
      if (r.status === 200 && r.data?.action === "ocultado") stats.ocultados++;
      continue;
    }
    stats.publicos++;
    publicUids.push(doc.id);
    const r = await pushProfessional(doc.id, d, secret, { reconcile: true });
    const action = r.data?.action;
    if (r.status !== 200) stats.falhas++;
    else if (action === "criado") stats.criados++;
    else if (action === "atualizado") stats.atualizados++;
    else if (action === "inalterado") stats.inalterados++;
  }
  // Oculta no site quem tem uid sincronizado mas não está mais na lista aprovada.
  if (publicUids.length > 0 && stats.falhas === 0) {
    const r = await post("/profissionais/reconciliar", { completo: true, uids: publicUids }, secret);
    if (r.status === 200) stats.ocultados += r.data?.ocultados || 0;
  }
  console.log("site_sync reconciliação:", JSON.stringify(stats));
  return stats;
}

exports.syncProfessionalsToSite = onSchedule(
  { schedule: "every 6 hours", timeZone: "America/Sao_Paulo", region: "southamerica-east1", secrets: [SITE_SECRET], timeoutSeconds: 540 },
  async () => { await reconcileAll(SITE_SECRET.value()); }
);

// Disparo manual (mesmo segredo do site): curl -X POST -H "X-VetVem-Secret: ..." <url>
exports.syncProfessionalsNow = onRequest(
  { region: "southamerica-east1", secrets: [SITE_SECRET], timeoutSeconds: 540 },
  async (req, res) => {
    if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });
    const sent = String(req.headers["x-vetvem-secret"] || "");
    const secret = SITE_SECRET.value();
    const ok = sent.length === secret.length && crypto.timingSafeEqual(Buffer.from(sent), Buffer.from(secret));
    if (!ok) return res.status(401).json({ error: "Não autorizado" });
    try {
      return res.json(await reconcileAll(secret));
    } catch (e) {
      console.error("syncProfessionalsNow erro:", e.message);
      return res.status(500).json({ error: e.message });
    }
  }
);
