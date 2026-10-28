// Regras puras (sem Firestore/rede) do DESLOCAMENTO POR KM.
// O profissional escolhe: taxa fixa (como sempre) ou valor por km, só ida ou ida e volta.
// O VetVem limita o valor por km e o total do deslocamento (config/travel_rules).

const DEFAULT_RULES = {
  maxPerKm: 3,          // R$ por km: teto que o profissional pode cobrar
  maxTotal: 80,         // R$: teto do deslocamento em um atendimento
  fallbackFactor: 1.3,  // distância por estrada ≈ linha reta × fator (plano B)
  maxRadiusKm: 100,     // raio máximo aceito, por mais que o profissional peça
};

const num = (v) => {
  const n = parseFloat(String(v === undefined || v === null ? "" : v).replace(",", "."));
  return Number.isFinite(n) ? n : 0;
};

// Mistura config/travel_rules com os padrões, ignorando valores inválidos.
function mergeRules(cfg) {
  const out = { ...DEFAULT_RULES };
  for (const k of Object.keys(DEFAULT_RULES)) {
    const v = num(cfg && cfg[k]);
    if (v > 0) out[k] = v;
  }
  return out;
}

// "20040-020" / "20040020" -> "20040020"; null se não tiver 8 dígitos.
function normalizeCep(v) {
  const d = String(v === undefined || v === null ? "" : v).replace(/\D/g, "");
  return d.length === 8 ? d : null;
}

// Distância em linha reta (km) entre dois pontos {lat,lng}.
function haversineKm(a, b) {
  const R = 6371;
  const rad = (x) => (x * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(h)));
}

const round1 = (n) => Math.round(n * 10) / 10;
const round2 = (n) => Math.round(n * 100) / 100;

// Configuração de deslocamento do profissional (users/{id}) já validada.
// Retorna null se ele usa taxa fixa (ou a configuração por km está incompleta).
function vetTravelConfig(vet, rules) {
  if (!vet || vet.travelModel !== "per_km") return null;
  const perKm = num(vet.travelPerKm);
  if (!(perKm > 0)) return null;
  const maxKm = num(vet.travelMaxKm);
  return {
    perKm: Math.min(perKm, rules.maxPerKm),
    roundTrip: vet.travelRoundTrip === true,
    maxKm: maxKm > 0 ? Math.min(maxKm, rules.maxRadiusKm) : rules.maxRadiusKm,
  };
}

// Valor do deslocamento para uma distância (km, um sentido).
// Retorna { fee, km, billedKm, perKm, roundTrip, capped, outOfRange }.
function feeForDistance(km, cfg, rules) {
  const dist = round1(Math.max(0, Number(km) || 0));
  if (dist > cfg.maxKm) {
    return { fee: 0, km: dist, billedKm: 0, perKm: cfg.perKm, roundTrip: cfg.roundTrip, capped: false, outOfRange: true };
  }
  const billedKm = cfg.roundTrip ? dist * 2 : dist;
  const raw = round2(billedKm * cfg.perKm);
  const fee = Math.min(raw, rules.maxTotal);
  return {
    fee: round2(fee), km: dist, billedKm: round1(billedKm), perKm: cfg.perKm,
    roundTrip: cfg.roundTrip, capped: raw > rules.maxTotal, outOfRange: false,
  };
}

module.exports = {
  DEFAULT_RULES, mergeRules, normalizeCep, haversineKm, vetTravelConfig, feeForDistance, round1, round2, num,
};
