// Deslocamento por km — acesso ao Firestore e ao mapa (NÃO exporta Cloud Functions:
// os endpoints ficam em travel.js). Fluxo:
//   CEP -> coordenadas (cache em cep_geo/{cep}: BrasilAPI; plano B ViaCEP + geocodificação ORS)
//   coordenadas -> km por estrada (OpenRouteService; cache em travel_cache/{origem}_{destino})
//   se o serviço de rotas falhar: linha reta × fator (marcado como estimativa, não vai ao cache)
// Coleções privadas (sem regra de cliente): cep_geo, travel_cache, vet_origins, travel_usage.
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const axios = require("axios");
const T = require("./travel_lib");

const ORS = "https://api.heigit.org/openrouteservice";   // rotas (o endereço antigo está sendo desativado)
const ORS_GEOCODE = "https://api.openrouteservice.org"; // geocodificação ainda só existe no endereço antigo
const DAILY_LOOKUPS_PER_USER = 60; // consultas externas novas por usuário/dia (proteção da cota grátis)

const ORS_SECRET = defineSecret("ORS_API_KEY");
// Chave do OpenRouteService: só existe nas funções que listam ORS_SECRET em `secrets`.
const orsKey = () => { try { return ORS_SECRET.value() || null; } catch (_) { return null; } };
// Chave da AwesomeAPI (CEP -> coordenada da rua). Sem ela a cota é compartilhada com outros IPs do Google e dá 429.
const AWESOME_SECRET = defineSecret("AWESOME_API_KEY");
const awesomeKey = () => { try { return AWESOME_SECRET.value() || null; } catch (_) { return null; } };

const db = () => admin.firestore();

async function loadRules() {
  try {
    const d = (await db().collection("config").doc("travel_rules").get()).data();
    return T.mergeRules(d);
  } catch (e) {
    console.error("travel loadRules:", e.message);
    return T.mergeRules(null);
  }
}

const inBrazil = (p) => p && p.lat > -34 && p.lat < 6 && p.lng > -74 && p.lng < -28;

// AwesomeAPI: coordenadas por CEP no nível da RUA (a BrasilAPI devolve o centro da cidade para
// muitos CEPs, o que zerava a distância entre dois endereços da mesma cidade).
async function viaAwesomeApi(cep) {
  try {
    const key = awesomeKey();
    const r = await axios.get(`https://cep.awesomeapi.com.br/json/${cep}`, {
      timeout: 6000, headers: key ? { "x-api-key": key } : {},
    });
    const p = r.data ? { lat: parseFloat(r.data.lat), lng: parseFloat(r.data.lng) } : null;
    return inBrazil(p) ? p : null;
  } catch (e) {
    console.error("travel geocode Awesome:", e.response ? e.response.status : e.message);
    return null;
  }
}

async function viaBrasilApi(cep) {
  try {
    const r = await axios.get(`https://brasilapi.com.br/api/cep/v2/${cep}`, { timeout: 6000 });
    const c = r.data && r.data.location && r.data.location.coordinates;
    const p = c ? { lat: parseFloat(c.latitude), lng: parseFloat(c.longitude) } : null;
    return inBrazil(p) ? p : null;
  } catch (_) { return null; }
}

async function viaOrsGeocode(cep, orsKey) {
  if (!orsKey) return null;
  try {
    let text = `${cep.slice(0, 5)}-${cep.slice(5)}, Brasil`;
    try {
      const v = (await axios.get(`https://viacep.com.br/ws/${cep}/json/`, { timeout: 6000 })).data || {};
      if (!v.erro && v.localidade) {
        text = [v.logradouro, v.bairro, `${v.localidade} - ${v.uf}`, "Brasil"].filter(Boolean).join(", ");
      }
    } catch (_) { /* segue só com o CEP */ }
    const r = await axios.get(`${ORS_GEOCODE}/geocode/search`, {
      params: { api_key: orsKey, text, "boundary.country": "BR", size: 1 }, timeout: 8000,
    });
    const g = r.data && r.data.features && r.data.features[0] && r.data.features[0].geometry;
    const p = g && Array.isArray(g.coordinates) ? { lat: Number(g.coordinates[1]), lng: Number(g.coordinates[0]) } : null;
    return inBrazil(p) ? p : null;
  } catch (e) {
    console.error("travel geocode ORS:", e.message);
    return null;
  }
}

// CEP (8 dígitos) -> {lat,lng} ou null. Resultado positivo vai ao cache.
async function geocodeCep(cep, orsKey) {
  const ref = db().collection("cep_geo").doc(cep);
  const hit = (await ref.get()).data();
  // v:2 = coordenadas da AwesomeAPI/mais precisas; entradas antigas (sem v) eram imprecisas e são refeitas
  if (hit && hit.v === 3 && Number.isFinite(hit.lat) && Number.isFinite(hit.lng)) return { lat: hit.lat, lng: hit.lng };
  const precise = await viaAwesomeApi(cep);
  if (precise) {
    await ref.set({ lat: precise.lat, lng: precise.lng, v: 3, at: Date.now() });
    return precise;
  }
  // Plano B: BrasilAPI costuma devolver só o centro da cidade (imprecisa) — serve de estimativa, mas NÃO vai ao cache
  return (await viaBrasilApi(cep)) || (await viaOrsGeocode(cep, orsKey));
}

// Distância por estrada (km) entre dois pontos, ou null se o serviço falhar.
async function routeKm(a, b, orsKey) {
  if (!orsKey) return null;
  try {
    const r = await axios.post(
      `${ORS}/v2/directions/driving-car`,
      { coordinates: [[a.lng, a.lat], [b.lng, b.lat]] },
      { headers: { Authorization: orsKey, "Content-Type": "application/json" }, timeout: 8000 }
    );
    const m = r.data && r.data.routes && r.data.routes[0] && r.data.routes[0].summary &&
      r.data.routes[0].summary.distance;
    return Number.isFinite(m) && m >= 0 ? m / 1000 : null;
  } catch (e) {
    console.error("travel route ORS:", e.message);
    return null;
  }
}

const today = () => new Date(Date.now() - 3 * 3600e3).toISOString().slice(0, 10).replace(/-/g, "");

// Conta uma consulta externa do usuário no dia; false se passou do limite.
async function allowLookup(uid) {
  if (!uid) return true;
  const ref = db().collection("travel_usage").doc(`${uid}_${today()}`);
  const n = Number(((await ref.get()).data() || {}).n) || 0;
  if (n >= DAILY_LOOKUPS_PER_USER) return false;
  await ref.set({ n: n + 1, at: Date.now() });
  return true;
}

// Coordenadas privadas de origem do profissional (vet_origins/{uid}), gravadas por geocodeVetOrigin.
async function vetOrigin(vetId, orsKey) {
  const ref = db().collection("vet_origins").doc(vetId);
  const o = (await ref.get()).data();
  if (!o || !T.normalizeCep(o.cep)) return null;
  if (o.v === 3 && Number.isFinite(o.lat) && Number.isFinite(o.lng)) return o;
  // coordenada antiga (imprecisa): refaz a partir do CEP
  const p = await geocodeCep(o.cep, orsKey);
  if (!p) return null;
  const fresh = { lat: p.lat, lng: p.lng, cep: o.cep, v: 3, at: Date.now() };
  await ref.set(fresh);
  return fresh;
}

// Cota o deslocamento do profissional `vetId` até o CEP do tutor.
// opts: { orsKey, uid, vet (users/{vetId} já lido), rules, noExternal }
//   noExternal: só usa cache/estimativa local (não gasta cota) — usado ao listar alternativas.
// Retorna:
//   { ok:true, mode:"fixed" }                       profissional usa taxa fixa
//   { ok:true, mode:"per_km", fee, km, billedKm, perKm, roundTrip, capped, outOfRange, source }
//   { ok:false, error:"cep_invalido"|"origem_ausente"|"destino_nao_encontrado"|"limite" }
async function quoteTravel(vetId, destCepRaw, opts = {}) {
  const rules = opts.rules || (await loadRules());
  const key0 = opts.orsKey || orsKey();
  const vet = opts.vet || (await db().collection("users").doc(vetId).get()).data() || {};
  const cfg = T.vetTravelConfig(vet, rules);
  if (!cfg) return { ok: true, mode: "fixed" };

  const destCep = T.normalizeCep(destCepRaw);
  if (!destCep) return { ok: false, error: "cep_invalido" };
  const origin = await vetOrigin(vetId, key0);
  if (!origin || !T.normalizeCep(origin.cep)) return { ok: false, error: "origem_ausente" };

  const key = `${origin.cep}_${destCep}_3`;
  const cacheRef = db().collection("travel_cache").doc(key);
  const cached = (await cacheRef.get()).data();
  let km = cached && Number.isFinite(cached.km) ? cached.km : null;
  let source = "route";

  if (km === null) {
    // coordenadas do destino: cache primeiro; só consulta fora se couber na cota
    let dest = null;
    const geoHit = (await db().collection("cep_geo").doc(destCep).get()).data();
    if (geoHit && geoHit.v === 3 && Number.isFinite(geoHit.lat)) dest = { lat: geoHit.lat, lng: geoHit.lng };
    if (!dest) {
      if (opts.noExternal) return { ok: false, error: "destino_nao_encontrado" };
      if (!(await allowLookup(opts.uid))) return { ok: false, error: "limite" };
      dest = await geocodeCep(destCep, key0);
      if (!dest) return { ok: false, error: "destino_nao_encontrado" };
    }
    let road = null;
    if (!opts.noExternal) {
      if (!(await allowLookup(opts.uid))) return { ok: false, error: "limite" };
      road = await routeKm(origin, dest, key0);
    }
    if (road !== null) {
      km = road;
      await cacheRef.set({ km, at: Date.now() });
    } else {
      km = T.haversineKm(origin, dest) * rules.fallbackFactor; // plano B: estimativa
      source = "estimate";
    }
  }
  return { ok: true, mode: "per_km", source, ...T.feeForDistance(km, cfg, rules) };
}

module.exports = { ORS_SECRET, AWESOME_SECRET, orsKey, loadRules, geocodeCep, routeKm, vetOrigin, quoteTravel, allowLookup, DAILY_LOOKUPS_PER_USER };
