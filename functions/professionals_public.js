// Espelho PÚBLICO dos profissionais: professionals_public/{uid}.
//
// users/{uid} guarda dados privados (telefone, e-mail, endereço, PIX, termos).
// Para que tutores e o portal possam buscar profissionais SEM ler users/{uid},
// esta coleção guarda só os campos de vitrine, mantida aqui (Admin SDK) — as
// regras do Firestore não permitem escrita de clientes.
//
// Regra de existência: o doc existe SE E SOMENTE SE o profissional está
// aprovado ('approved' ou 'active' legado) e não bloqueado. Pendente, rejeitado,
// bloqueado ou apagado => doc removido. Por isso os clientes não precisam (nem
// conseguem) ver accountStatus/blocked de ninguém.
//
// Os campos são uma lista BRANCA explícita (buildPublicDoc). Campo novo em
// users/{uid} NUNCA vira público por acidente.
//
// Duas vias, como em site_sync.js:
//  - mirrorProfessionalPublic: tempo real, a cada escrita em users/{uid};
//  - reconcileProfessionalsPublic: a cada 24h (e sob demanda em
//    reconcileProfessionalsPublicNow) — backfill inicial, repara falhas e
//    remove órfãos.
//
// (v3: inclui deslocamento por km)
// ATENÇÃO: isPublic() é o MESMO critério de site_sync.js (duplicado de
// propósito: site_sync não exporta helpers, e tudo que ele exporta vira
// Cloud Function via Object.assign em index.js). Mudou lá, mude aqui.

const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const crypto = require("crypto");

// Mesmo segredo do syncProfessionalsNow (já provisionado no projeto).
const SYNC_SECRET = defineSecret("WP_SYNC_SECRET");

const COLLECTION = "professionals_public";

function isPublic(d) {
  return !!d && d.role === "professional" &&
    (d.accountStatus === "approved" || d.accountStatus === "active") &&
    d.blocked !== true;
}

const arr = (v) => (Array.isArray(v) ? v : []);
const str = (v) => (typeof v === "string" ? v : "");
const num = (v) => (typeof v === "number" && Number.isFinite(v) ? v : 0);

// Serviços: nome/preço/unidade (+ perAnimal/additionalPrice/travelFee/instructions). Preço pode estar salvo como string.
function servicesOf(d) {
  return arr(d.services)
    .filter((s) => s && typeof s === "object")
    .map((s) => {
      const out = {
        name: str(s.name),
        price: s.price === undefined || s.price === null ? "0" : String(s.price),
        unit: str(s.unit) || "consulta",
      };
      // Serviço cobrado por animal (vacina, vermífugo...): o app tutor e o portal
      // precisam disso para permitir vários animais e calcular o total.
      if (s.perAnimal === true) out.perAnimal = true;
      if (s.additionalPrice !== undefined && s.additionalPrice !== null &&
          String(s.additionalPrice).trim() !== "") {
        out.additionalPrice = String(s.additionalPrice);
      }
      // Taxa de deslocamento fixa e orientações ao tutor: o tutor precisa ver ANTES de pagar.
      if (s.travelFee !== undefined && s.travelFee !== null && String(s.travelFee).trim() !== "") {
        out.travelFee = String(s.travelFee);
      }
      // Deslocamento por km: só os serviços marcados cobram (o profissional escolhe serviço a serviço).
      if (s.travelByKm === true) out.travelByKm = true;
      const instr = str(s.instructions).trim().slice(0, 240);
      if (instr) out.instructions = instr;
      return out;
    });
}

// Área de atuação (estado/cidades/bairros) — já é pública no site. Reconstruída
// campo a campo para não carregar chave inesperada.
function areaOf(d) {
  const a = d.area_atuacao;
  if (!a || typeof a !== "object") return null;
  return {
    estado: str(a.estado),
    cidades: arr(a.cidades)
      .filter((c) => c && typeof c === "object")
      .map((c) => ({
        nome: str(c.nome),
        ibge_id: c.ibge_id === undefined || c.ibge_id === null ? "" : String(c.ibge_id),
        atende_cidade_toda: c.atende_cidade_toda === true,
        bairros: arr(c.bairros).map(String),
      })),
  };
}

// Deslocamento por km: só modelo e condições (valor por km, ida e volta, raio). O CEP de
// origem e as coordenadas NUNCA entram aqui (ficam em vet_origins, privado). O valor final
// vem sempre de travelQuote, que também aplica os tetos do VetVem.
function travelOf(d) {
  const perKm = parseFloat(String(d.travelPerKm === undefined || d.travelPerKm === null ? "" : d.travelPerKm).replace(",", "."));
  if (d.travelModel !== "per_km" || !(perKm > 0)) return {};
  const maxKm = parseFloat(String(d.travelMaxKm === undefined || d.travelMaxKm === null ? "" : d.travelMaxKm).replace(",", "."));
  return {
    travelModel: "per_km",
    travelPerKm: perKm,
    travelRoundTrip: d.travelRoundTrip === true,
    ...(maxKm > 0 ? { travelMaxKm: maxKm } : {}),
  };
}

// Lista branca. NUNCA adicionar: phone, email, address, pixKeys, termos_*,
// fcmToken, platform, feeOverride, pixChangedAt, createdAt, accountStatus.
function buildPublicDoc(d) {
  return {
    ...travelOf(d),
    name: str(d.name), // sem trim: o app casa avaliações por vetName exato
    crmv: str(d.crmv),
    bio: str(d.bio),
    categories: arr(d.categories).map(String),
    services: servicesOf(d),
    animalSpecies: arr(d.animalSpecies).map(String),
    area_atuacao: areaOf(d),
    area_atuacao_keys: arr(d.area_atuacao_keys).map(String),
    availableDays: arr(d.availableDays).map(String),
    availableTimes: arr(d.availableTimes).map(String),
    photoBase64: str(d.photoBase64),
    photoUrl: str(d.photoUrl),
    isAvailable: d.isAvailable !== false,
    rating: num(d.rating),
    reviewCount: num(d.reviewCount),
    completedCount: num(d.completedCount),
  };
}

const sameDoc = (a, b) => JSON.stringify(a) === JSON.stringify(b);

// Grava (ou remove) o espelho de um profissional. Retorna a ação tomada.
async function syncOne(uid, userData, existingMirror) {
  const ref = admin.firestore().collection(COLLECTION).doc(uid);
  if (!isPublic(userData)) {
    if (existingMirror === false) return "nada"; // sabido que não existe
    await ref.delete(); // delete de doc inexistente é no-op
    return "removido";
  }
  const pub = buildPublicDoc(userData);
  if (existingMirror) {
    const { updatedAt, ...atual } = existingMirror; // eslint-disable-line no-unused-vars
    if (sameDoc(atual, pub)) return "inalterado";
  }
  // set SEM merge: campo que saiu da lista branca/foi apagado some do espelho.
  await ref.set({ ...pub, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
  return existingMirror ? "atualizado" : "criado";
}

exports.mirrorProfessionalPublic = onDocumentWritten(
  { document: "users/{uid}", region: "southamerica-east1", timeoutSeconds: 60 },
  async (event) => {
    const uid = event.params.uid;
    const before = event.data?.before?.exists ? event.data.before.data() : null;
    const after = event.data?.after?.exists ? event.data.after.data() : null;
    if (before?.role !== "professional" && after?.role !== "professional") return;

    if (!after) {
      // Perfil apagado: remove a vitrine.
      await admin.firestore().collection(COLLECTION).doc(uid).delete();
      return;
    }

    // Escritas irrelevantes (fcmToken, termos...) não mudam a vitrine: sai sem
    // ler/escrever nada. Só vale quando antes também era público.
    if (before && isPublic(before) && isPublic(after) &&
        sameDoc(buildPublicDoc(before), buildPublicDoc(after))) {
      return;
    }

    const snap = await admin.firestore().collection(COLLECTION).doc(uid).get();
    const action = await syncOne(uid, after, snap.exists ? snap.data() : false);
    if (action !== "inalterado" && action !== "nada") {
      console.log(`professionals_public: ${action} ${uid}`);
    }
  }
);

async function reconcileAll() {
  const db = admin.firestore();
  const stats = { profissionais: 0, publicos: 0, criados: 0, atualizados: 0, inalterados: 0, removidos: 0, orfaos: 0 };

  const mirrorSnap = await db.collection(COLLECTION).get();
  const mirror = new Map(mirrorSnap.docs.map((x) => [x.id, x.data()]));

  const users = await db.collection("users").where("role", "==", "professional").get();
  const seen = new Set();
  for (const doc of users.docs) {
    stats.profissionais++;
    seen.add(doc.id);
    const d = doc.data();
    const existing = mirror.has(doc.id) ? mirror.get(doc.id) : false;
    const action = await syncOne(doc.id, d, existing);
    if (isPublic(d)) stats.publicos++;
    if (action === "criado") stats.criados++;
    else if (action === "atualizado") stats.atualizados++;
    else if (action === "inalterado") stats.inalterados++;
    else if (action === "removido") stats.removidos++;
  }
  // Espelho sem users/{uid} correspondente (ex.: perfil apagado e trigger perdido).
  for (const id of mirror.keys()) {
    if (seen.has(id)) continue;
    await db.collection(COLLECTION).doc(id).delete();
    stats.orfaos++;
  }
  console.log("professionals_public reconciliação:", JSON.stringify(stats));
  return stats;
}

exports.reconcileProfessionalsPublic = onSchedule(
  { schedule: "every 24 hours", timeZone: "America/Sao_Paulo", region: "southamerica-east1", timeoutSeconds: 540 },
  async () => { await reconcileAll(); }
);

// Backfill / reparo sob demanda (mesmo segredo do syncProfessionalsNow):
//   curl -X POST -H "X-VetVem-Secret: ..." <url>
exports.reconcileProfessionalsPublicNow = onRequest(
  { region: "southamerica-east1", secrets: [SYNC_SECRET], timeoutSeconds: 540 },
  async (req, res) => {
    if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });
    const sent = String(req.headers["x-vetvem-secret"] || "");
    const secret = SYNC_SECRET.value();
    const ok = sent.length === secret.length &&
      crypto.timingSafeEqual(Buffer.from(sent), Buffer.from(secret));
    if (!ok) return res.status(401).json({ error: "Não autorizado" });
    try {
      return res.json(await reconcileAll());
    } catch (e) {
      console.error("reconcileProfessionalsPublicNow erro:", e.message);
      return res.status(500).json({ error: e.message });
    }
  }
);

// Só para teste unitário. index.js faz Object.assign(exports, require(...)),
// que copia apenas propriedades ENUMERÁVEIS — esta é não-enumerável, então não
// vira Cloud Function no deploy.
Object.defineProperty(exports, "__test", {
  value: { isPublic, buildPublicDoc },
  enumerable: false,
});
