// Leituras públicas que os apps faziam direto em `appointments` e que passam pelo servidor,
// para a coleção poder ser fechada (só dono, profissional e admin).
//   busyTimes   -> só os HORÁRIOS ocupados de um profissional num dia (sem dados de ninguém)
//   vetReviews  -> avaliações de um profissional (nota, comentário, primeiro nome do tutor, pet, data)

const BUSY_STATUSES = ["confirmed", "pending_confirmation"];

// docs: dados dos pedidos do profissional. date: "dd/mm/aaaa".
function pickBusyTimes(docs, date) {
  const out = new Set();
  for (const d of docs) {
    if (d.date === date && BUSY_STATUSES.includes(d.status || "") && typeof d.time === "string" && d.time) out.add(d.time);
  }
  return [...out].sort();
}

const firstName = (n) => String(n || "").trim().split(/\s+/)[0] || "Anônimo";

// dd/mm/aaaa -> aaaammdd (ordenar do mais novo para o mais antigo)
const dateKey = (s) => { const m = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(String(s || "")); return m ? m[3] + m[2] + m[1] : ""; };

function pickReviews(docs) {
  const rows = docs
    .filter((d) => typeof d.rating === "number" && d.rating > 0)
    .map((d) => ({
      rating: Math.round(d.rating),
      comment: String(d.comment || ""),
      tutorName: firstName(d.tutorName),
      petName: String(d.petName || ""),
      date: String(d.date || ""),
    }));
  rows.sort((a, b) => dateKey(b.date).localeCompare(dateKey(a.date)));
  const count = rows.length;
  const rating = count ? Math.round((rows.reduce((s, r) => s + r.rating, 0) / count) * 10) / 10 : 0;
  return { reviews: rows, rating, reviewCount: count };
}

// Agregados do profissional (mesma conta que o app fazia): nota média (1 casa), nº de avaliações
// e nº de atendimentos concluídos. docs = pedidos do profissional (por vetId e por vetName, sem repetir).
function aggregateVet(docs) {
  let sum = 0; let n = 0; let completed = 0;
  for (const d of docs) {
    if (d.status === "completed") completed++;
    if (typeof d.rating === "number" && d.rating > 0) { sum += d.rating; n++; }
  }
  return { rating: n ? Math.round((sum / n) * 10) / 10 : 0, reviewCount: n, completedCount: completed };
}

const validDate = (s) => /^\d{2}\/\d{2}\/\d{4}$/.test(String(s || ""));

module.exports = { pickBusyTimes, pickReviews, aggregateVet, validDate, firstName };
