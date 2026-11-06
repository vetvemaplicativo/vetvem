// Taxa do VetVem sobre repasses — fonte única usada por dailyPayouts (consultas) e
// dailyExtraPayouts (adicionais). A MESMA tabela existe no app Pro
// (home_controller.dart, feePercentFor): mudanças aqui precisam ser replicadas lá.
//
// Taxa regressiva por volume: consultas concluídas E pagas no MÊS ANTERIOR definem a taxa do
// mês atual do profissional.   1–9 → 15%  |  10–19 → 12%  |  20+ → 10%
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

// "23/06/2026" → Date (meio-dia de Brasília)
function parseApptDate(s) {
  const p = (s || "").split("/");
  if (p.length < 3) return null;
  const d = new Date(`${p[2]}-${p[1].padStart(2, "0")}-${p[0].padStart(2, "0")}T12:00:00-03:00`);
  return isNaN(d.getTime()) ? null : d;
}

// Consultas concluídas e pagas do profissional no mês anterior (mesma conta do dailyPayouts).
async function lastMonthCountForVet(db, vetId, now = new Date()) {
  const prevMonthStart = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const thisMonthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const snap = await db.collection("appointments").where("vetId", "==", vetId).get();
  let n = 0;
  for (const doc of snap.docs) {
    const d = doc.data();
    if (d.status !== "completed" || d.paymentStatus !== "approved") continue;
    const apptDate = parseApptDate(d.date);
    if (apptDate && apptDate >= prevMonthStart && apptDate < thisMonthStart) n++;
  }
  return n;
}

// Isenção/taxa customizada do profissional (feeOverride, com prazo opcional em feeOverrideUntil).
function activeOverride(userData) {
  const d = userData || {};
  if (d.feeOverride == null) return null;
  const until = d.feeOverrideUntil;
  const expired = until && until.toDate && until.toDate() < new Date();
  return expired ? null : d.feeOverride;
}

module.exports = { DEFAULT_TIERS, loadFeeTiers, feePercentFor, lastMonthCountForVet, activeOverride };
