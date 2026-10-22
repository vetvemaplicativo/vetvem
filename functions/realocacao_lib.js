// Regras puras (sem Firestore) da REALOCAÇÃO de profissional: quando o veterinário
// recusa ou não responde, o tutor escolhe outro profissional que atenda no MESMO
// dia e horário, com preço igual ou menor. Tudo em horário de Brasília (-03:00).

const { parseDateTimeMs } = require("./horarios_lib");
const { priceForService, toNum } = require("./appointment_amount");

const MAX_OPTIONS = 5;            // até 5 alternativas
const MAX_ROUNDS = 3;             // original + até 2 tentativas com novos profissionais
const TUTOR_WINDOW_MIN = 30;      // o tutor tem 30 min para escolher
const VET_RESPONSE_MIN = 120;     // novo profissional: até 2h para responder...
const VET_END_MARGIN_MIN = 60;    // ...mas nunca depois de 1h antes da consulta
const MIN_REMAINING_HOURS = 3;    // só oferece com >= 3h até a consulta (30 min tutor + resposta + margem)
const MIN_SIMILARITY = 0.5;       // semelhança mínima entre nomes de serviço
const MIN = 60 * 1000;
const HOUR = 60 * MIN;

const ACCENTS = {
  á: "a", à: "a", â: "a", ã: "a", ä: "a", é: "e", è: "e", ê: "e", ë: "e",
  í: "i", ì: "i", î: "i", ï: "i", ó: "o", ò: "o", ô: "o", õ: "o", ö: "o",
  ú: "u", ù: "u", û: "u", ü: "u", ç: "c", ñ: "n",
};

// Mesmo critério do app (normalizeSearchText): minúsculas, sem acento, espaços colapsados.
function normText(t) {
  let s = String(t === undefined || t === null ? "" : t).trim().toLowerCase();
  s = s.replace(/[áàâãäéèêëíìîïóòôõöúùûüçñ]/g, (c) => ACCENTS[c] || c);
  return s.replace(/\s+/g, " ");
}

const STOP = new Set(["de", "da", "do", "das", "dos", "para", "e", "a", "o", "em", "com", "no", "na", "por", "um", "uma"]);

function tokens(name) {
  return normText(name)
    .replace(/[^a-z0-9 ]/g, " ")
    .split(" ")
    .filter((w) => w && !STOP.has(w));
}

// 1 = nome igual; senão sobreposição de palavras (Jaccard). 0 = nada em comum.
function serviceSimilarity(a, b) {
  const na = normText(a).replace(/[^a-z0-9 ]/g, " ").replace(/\s+/g, " ").trim();
  const nb = normText(b).replace(/[^a-z0-9 ]/g, " ").replace(/\s+/g, " ").trim();
  if (!na || !nb) return 0;
  if (na === nb) return 1;
  const ta = new Set(tokens(a));
  const tb = new Set(tokens(b));
  if (ta.size === 0 || tb.size === 0) return 0;
  let inter = 0;
  for (const w of ta) if (tb.has(w)) inter++;
  const union = ta.size + tb.size - inter;
  return union === 0 ? 0 : inter / union;
}

// Espelha AreaAtuacao.cobreEndereco do app: a área do profissional cobre o endereço?
// area = professionals_public.area_atuacao { estado, cidades:[{nome, atende_cidade_toda, bairros}] }.
function coversAddress(area, uf, city, neighborhood) {
  if (!area || typeof area !== "object") return false;
  if (String(area.estado || "").trim().toUpperCase() !== String(uf || "").trim().toUpperCase()) return false;
  const cityN = normText(city);
  if (!cityN) return false;
  const hoodN = normText(neighborhood);
  for (const c of Array.isArray(area.cidades) ? area.cidades : []) {
    if (normText(c && c.nome) !== cityN) continue;
    if (c.atende_cidade_toda === true || !hoodN) return true;
    if ((Array.isArray(c.bairros) ? c.bairros : []).some((b) => normText(b) === hoodN)) return true;
  }
  return false;
}

const DAY_LABELS = ["Seg", "Ter", "Qua", "Qui", "Sex", "Sab", "Dom"];

// "23/06/2026" -> "Ter" (dia da semana em Brasília); null se inválido.
function weekdayLabel(dateStr) {
  const ms = parseDateTimeMs(dateStr, "12:00");
  if (ms === null) return null;
  const d = new Date(ms - 3 * HOUR); // relógio de Brasília lido como UTC
  return DAY_LABELS[(d.getUTCDay() + 6) % 7];
}

function padTime(t) {
  const m = /^(\d{1,2}):(\d{2})$/.exec(String(t || "").trim());
  return m ? `${m[1].padStart(2, "0")}:${m[2]}` : "";
}

// O profissional trabalha nesse dia e horário? Listas vazias = sem configuração (não bloqueia),
// igual ao app do tutor.
function worksAt(pub, dateStr, timeStr) {
  const days = Array.isArray(pub.availableDays) ? pub.availableDays : [];
  if (days.length > 0) {
    const w = weekdayLabel(dateStr);
    if (!w || !days.includes(w)) return false;
  }
  const times = (Array.isArray(pub.availableTimes) ? pub.availableTimes : []).map(padTime);
  if (times.length > 0 && !times.includes(padTime(timeStr))) return false;
  return true;
}

const sharesCategory = (a, b) => {
  const A = (Array.isArray(a) ? a : []).map(normText).filter(Boolean);
  const B = (Array.isArray(b) ? b : []).map(normText).filter(Boolean);
  if (A.length === 0 || B.length === 0) return true; // sem especialidade cadastrada: não bloqueia
  return A.some((x) => B.includes(x));
};

// Escolhe, entre os serviços do candidato, o que mais se parece com o pedido
// ORIGINAL e cujo total (para o mesmo nº de animais) não passa do valor pago.
// Retorna { name, amount, travel, similarity } ou null.
function pickService(services, originalServiceName, appt, maxAmount) {
  let best = null;
  for (const s of Array.isArray(services) ? services : []) {
    if (!s || !s.name) continue;
    const sim = serviceSimilarity(originalServiceName, s.name);
    if (sim < MIN_SIMILARITY) continue;
    // O preço é calculado como no pagamento (inclui deslocamento e vários animais).
    const priced = priceForService(s, { ...appt, feesDisclosed: true });
    if (!priced || !(priced.amount > 0)) continue;
    if (priced.amount > maxAmount + 0.009) continue; // nunca mais caro que o valor pago
    const cand = { name: String(s.name), amount: priced.amount, travel: priced.travel, similarity: sim };
    if (!best || cand.similarity > best.similarity ||
        (cand.similarity === best.similarity && cand.amount < best.amount)) best = cand;
  }
  return best;
}

// Monta a lista final: mais baratos primeiro, depois melhor avaliados; no máximo 5.
function rankCandidates(list) {
  return [...list]
    .sort((a, b) =>
      a.price - b.price ||
      (Number(b.rating) || 0) - (Number(a.rating) || 0) ||
      String(a.vetName).localeCompare(String(b.vetName), "pt-BR"))
    .slice(0, MAX_OPTIONS);
}

// O pedido pode entrar em realocação agora? (checagens baratas, antes de ir ao banco)
// Retorna { ok:true } ou { ok:false, why }.
function canRelocate(appt, nowMs) {
  if (!appt) return { ok: false, why: "sem pedido" };
  if (appt.canRelocate !== true) return { ok: false, why: "app sem realocação" };
  if (appt.bookingOrigin === "portal_web") return { ok: false, why: "portal" };
  if (appt.paymentStatus !== "approved" || !appt.paymentId) return { ok: false, why: "não pago" };
  if (!appt.addrUf || !appt.addrCity) return { ok: false, why: "sem endereço estruturado" };
  if ((Number(appt.relocationRound) || 0) >= MAX_ROUNDS - 1) return { ok: false, why: "limite de tentativas" };
  const ms = parseDateTimeMs(appt.date, appt.time);
  if (ms === null) return { ok: false, why: "data inválida" };
  if (ms - nowMs < MIN_REMAINING_HOURS * HOUR) return { ok: false, why: "pouco tempo até a consulta" };
  return { ok: true };
}

// Valor pago (número) de um pedido.
function paidAmount(appt) {
  const p = toNum(appt.paymentAmount);
  return p > 0 ? p : toNum(appt.value);
}

// Prazo do tutor (ms).
function tutorDeadline(nowMs) {
  return nowMs + TUTOR_WINDOW_MIN * MIN;
}

// Prazo do novo profissional (ms): 2h, mas nunca depois de 1h antes da consulta.
function vetDeadline(nowMs, apptMs) {
  return Math.min(nowMs + VET_RESPONSE_MIN * MIN, apptMs - VET_END_MARGIN_MIN * MIN);
}

// "dd/MM às HH:mm" para textos.
function formatDeadline(ms) {
  const d = new Date(ms - 3 * HOUR);
  const two = (n) => String(n).padStart(2, "0");
  return `${two(d.getUTCHours())}:${two(d.getUTCMinutes())}`;
}

// "1234.5" -> "1234,50" (formato guardado em appointments.value)
function moneyString(n) {
  return (Math.round(Number(n) * 100) / 100).toFixed(2).replace(".", ",");
}

module.exports = {
  MAX_OPTIONS, MAX_ROUNDS, TUTOR_WINDOW_MIN, VET_RESPONSE_MIN, VET_END_MARGIN_MIN, MIN_REMAINING_HOURS,
  normText, serviceSimilarity, coversAddress, weekdayLabel, worksAt, sharesCategory,
  pickService, rankCandidates, canRelocate, paidAmount, tutorDeadline, vetDeadline, formatDeadline, moneyString,
};
