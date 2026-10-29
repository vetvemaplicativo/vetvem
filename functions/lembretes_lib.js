// Lembretes de consulta — regras puras (sem Firestore), testadas em test/lembretes.test.js.
//   vet_1d   profissional, na véspera às 18h
//   vet_2h   profissional, 2h antes
//   tutor_1d tutor, na véspera às 18h (inclui as orientações do profissional)
//   tutor_1h tutor, 1h antes
// A rotina (lembretes.js) roda a cada 15 min e grava em appointments/{id}.remindersSent.{chave}
// o que já foi enviado, então cada aviso sai uma vez só.

const HOUR = 3600e3;
const MIN = 60e3;

// "dd/MM/yyyy" + "HH:mm" (horário de Brasília, UTC-3) -> Date, ou null
function parseApptDateTime(dateStr, timeStr) {
  const p = String(dateStr || "").split("/");
  if (p.length < 3) return null;
  const [hh, mm] = String(timeStr || "23:59").split(":").map((v) => parseInt(v, 10));
  const h = Number.isFinite(hh) ? hh : 23;
  const m = Number.isFinite(mm) ? mm : 59;
  const d = new Date(
    `${p[2]}-${p[1].padStart(2, "0")}-${p[0].padStart(2, "0")}` +
    `T${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}:00-03:00`
  );
  return isNaN(d.getTime()) ? null : d;
}

// Hora (0-23) em Brasília
const brtHour = (now) => new Date(now.getTime() - 3 * HOUR).getUTCHours();

// Só consultas confirmadas e pagas recebem lembrete.
function eligible(appt) {
  return !!appt && appt.status === "confirmed" && appt.paymentStatus === "approved";
}

// Quais lembretes (chaves) estão no prazo agora e ainda não foram enviados.
// `now` é injetado para teste.
function remindersDue(appt, now) {
  if (!eligible(appt)) return [];
  const at = parseApptDateTime(appt.date, appt.time);
  if (!at) return [];
  const diff = at.getTime() - now.getTime();
  if (diff <= 0) return []; // já começou
  const sent = appt.remindersSent || {};
  const out = [];

  // Véspera às 18h: janela aberta entre 18h do dia anterior e 3h antes da consulta; nunca de
  // madrugada (7h–21h). Consulta marcada em cima da hora só recebe o aviso curto.
  const midnight = parseApptDateTime(appt.date, "00:00");
  const dayBefore18 = midnight ? new Date(midnight.getTime() - 6 * HOUR) : null;
  const quiet = brtHour(now) < 7 || brtHour(now) >= 21;
  const oneDayOpen = dayBefore18 && now >= dayBefore18 && diff >= 3 * HOUR && !quiet;
  if (oneDayOpen) {
    if (!sent.vet_1d) out.push("vet_1d");
    if (!sent.tutor_1d) out.push("tutor_1d");
  }

  // 2h antes (profissional) e 1h antes (tutor); não avisa quando faltam menos de 15 min.
  if (diff <= 2 * HOUR && diff > 15 * MIN && !sent.vet_2h) out.push("vet_2h");
  if (diff <= 1 * HOUR && diff > 15 * MIN && !sent.tutor_1h) out.push("tutor_1h");
  return out;
}

const firstName = (s) => String(s || "").trim().split(/\s+/)[0] || "";

// Texto de cada aviso. `pet` = rótulo do(s) animal(is) (ex.: "Rex +1").
function buildMessage(key, appt, pet) {
  const when = `${appt.date || ""} às ${appt.time || ""}`;
  const time = appt.time || "";
  const addr = String(appt.address || "").trim();
  const tutor = firstName(appt.tutorName);
  const vet = String(appt.vetName || "").trim();
  switch (key) {
    case "vet_1d":
      return {
        title: "📅 Consulta amanhã",
        body: `Amanhã, às ${time}: ${pet}${tutor ? ` (tutor ${tutor})` : ""}.${addr ? ` Endereço: ${addr}.` : ""}`,
      };
    case "vet_2h":
      return {
        title: "⏰ Consulta em 2 horas",
        body: `Hoje às ${time}: ${pet}${tutor ? ` (tutor ${tutor})` : ""}.${addr ? ` Endereço: ${addr}.` : ""}`,
      };
    case "tutor_1d": {
      const ori = String(appt.instructionsText || "").trim();
      return {
        title: "📅 Sua consulta é amanhã",
        body: `${pet} tem consulta ${vet ? `com ${vet} ` : ""}amanhã, às ${time}.${ori ? ` Lembrete do veterinário: ${ori}` : ""}`.trim(),
      };
    }
    case "tutor_1h":
      return {
        title: "⏰ Consulta daqui a pouco",
        body: `A consulta de ${pet} ${vet ? `com ${vet} ` : ""}é hoje às ${time}. Deixe o animal por perto e o endereço acessível.`,
      };
    default:
      return { title: "Consulta", body: `Consulta de ${pet} em ${when}.` };
  }
}

// Quem recebe cada chave
const AUDIENCE = { vet_1d: "vet", vet_2h: "vet", tutor_1d: "tutor", tutor_1h: "tutor" };

module.exports = { parseApptDateTime, remindersDue, buildMessage, eligible, AUDIENCE, brtHour };
