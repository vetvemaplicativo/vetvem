// Regras puras (sem Firestore) da "sugestão de novos horários": o profissional
// propõe até 3 datas/horários quando não pode no horário pedido; o tutor escolhe
// um (ou pede estorno). Tudo em horário de Brasília (-03:00, sem horário de verão).

const MAX_OPTIONS = 3;
const MIN_LEAD_HOURS = 3;     // o profissional só sugere horários com >= 3h de antecedência
const WINDOW_HOURS = 24;      // tutor tem até 24h para escolher...
const END_MARGIN_HOURS = 1;   // ...mas nunca depois de 1h antes do 1º horário sugerido
const MAX_DAYS_AHEAD = 60;
const HOUR = 60 * 60 * 1000;

// "23/06/2026" + "14:00" -> ms (UTC) no fuso de Brasília; null se inválido.
function parseDateTimeMs(dateStr, timeStr) {
  const m = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(String(dateStr || "").trim());
  const t = /^(\d{1,2}):(\d{2})$/.exec(String(timeStr || "").trim());
  if (!m || !t) return null;
  const [dd, mm, yyyy] = [m[1].padStart(2, "0"), m[2].padStart(2, "0"), m[3]];
  const [hh, mi] = [t[1].padStart(2, "0"), t[2]];
  if (Number(hh) > 23 || Number(mi) > 59) return null;
  const ms = new Date(`${yyyy}-${mm}-${dd}T${hh}:${mi}:00-03:00`).getTime();
  if (!Number.isFinite(ms)) return null;
  // rejeita 31/02 etc. (o Date "rola" para o mês seguinte)
  const back = new Date(ms - 3 * HOUR);
  if (back.getUTCDate() !== Number(dd) || back.getUTCMonth() + 1 !== Number(mm)) return null;
  return ms;
}

// Formata "dd/MM/yyyy" e "HH:mm" normalizados (zeros à esquerda).
function normalize(dateStr, timeStr) {
  const m = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(String(dateStr).trim());
  const t = /^(\d{1,2}):(\d{2})$/.exec(String(timeStr).trim());
  return {
    date: `${m[1].padStart(2, "0")}/${m[2].padStart(2, "0")}/${m[3]}`,
    time: `${t[1].padStart(2, "0")}:${t[2]}`,
  };
}

// options: [{date, time}] vindo do app. appt: pedido (date/time atuais).
// Retorna { ok:true, options:[{date,time,ms}] } ou { ok:false, error }.
function validateOptions(options, appt, nowMs) {
  if (!Array.isArray(options) || options.length < 1 || options.length > MAX_OPTIONS) {
    return { ok: false, error: `Envie de 1 a ${MAX_OPTIONS} horários.` };
  }
  const out = [];
  const seen = new Set();
  const current = appt && appt.date && appt.time ? normalize(appt.date, appt.time) : null;
  for (const o of options) {
    const ms = parseDateTimeMs(o && o.date, o && o.time);
    if (ms === null) return { ok: false, error: "Data ou horário inválido." };
    const n = normalize(o.date, o.time);
    const key = `${n.date} ${n.time}`;
    if (seen.has(key)) return { ok: false, error: "Há horários repetidos." };
    seen.add(key);
    if (current && n.date === current.date && n.time === current.time) {
      return { ok: false, error: "Um dos horários é o mesmo que o tutor pediu." };
    }
    if (ms < nowMs + MIN_LEAD_HOURS * HOUR) {
      return { ok: false, error: `Sugira horários com pelo menos ${MIN_LEAD_HOURS} horas de antecedência.` };
    }
    if (ms > nowMs + MAX_DAYS_AHEAD * 24 * HOUR) {
      return { ok: false, error: "Horário distante demais." };
    }
    out.push({ ...n, ms });
  }
  out.sort((a, b) => a.ms - b.ms);
  return { ok: true, options: out };
}

// Prazo do tutor: 24h depois da sugestão, nunca depois de 1h antes do 1º horário.
function computeDeadline(nowMs, firstOptionMs) {
  return Math.min(nowMs + WINDOW_HOURS * HOUR, firstOptionMs - END_MARGIN_HOURS * HOUR);
}

// "21/10 às 14:30" no fuso de Brasília.
function formatDeadline(ms) {
  const parts = new Intl.DateTimeFormat("pt-BR", {
    timeZone: "America/Sao_Paulo", day: "2-digit", month: "2-digit",
    hour: "2-digit", minute: "2-digit", hour12: false,
  }).formatToParts(new Date(ms));
  const g = (t) => (parts.find((p) => p.type === t) || {}).value || "";
  return `${g("day")}/${g("month")} às ${g("hour")}:${g("minute")}`;
}

module.exports = {
  MAX_OPTIONS, MIN_LEAD_HOURS, WINDOW_HOURS, END_MARGIN_HOURS,
  parseDateTimeMs, normalize, validateOptions, computeDeadline, formatDeadline,
};
