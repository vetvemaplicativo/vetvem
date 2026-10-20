const test = require("node:test");
const assert = require("node:assert");
const {
  parseDateTimeMs, validateOptions, computeDeadline, formatDeadline, normalize,
} = require("../horarios_lib");

// "agora" fixo: 20/10/2026 10:00 em Brasília
const NOW = parseDateTimeMs("20/10/2026", "10:00");
const APPT = { date: "21/10/2026", time: "11:00" };

test("parseDateTimeMs: fuso de Brasília e datas inválidas", () => {
  assert.equal(new Date(NOW).toISOString(), "2026-10-20T13:00:00.000Z");
  assert.equal(parseDateTimeMs("31/02/2026", "10:00"), null);
  assert.equal(parseDateTimeMs("21/10/2026", "25:00"), null);
  assert.equal(parseDateTimeMs("abc", "10:00"), null);
  assert.deepEqual(normalize("1/2/2026", "9:30"), { date: "01/02/2026", time: "9:30".padStart(5, "0") });
});

test("3 horários válidos, ordenados", () => {
  const r = validateOptions(
    [{ date: "23/10/2026", time: "10:00" }, { date: "21/10/2026", time: "14:00" }, { date: "22/10/2026", time: "09:00" }],
    APPT, NOW);
  assert.equal(r.ok, true);
  assert.deepEqual(r.options.map((o) => `${o.date} ${o.time}`),
    ["21/10/2026 14:00", "22/10/2026 09:00", "23/10/2026 10:00"]);
});

test("rejeita: vazio, mais de 3, repetido, igual ao pedido, passado/pouca antecedência, longe demais", () => {
  assert.equal(validateOptions([], APPT, NOW).ok, false);
  const four = ["21", "22", "23", "24"].map((d) => ({ date: `${d}/10/2026`, time: "15:00" }));
  assert.equal(validateOptions(four, APPT, NOW).ok, false);
  const dup = [{ date: "22/10/2026", time: "09:00" }, { date: "22/10/2026", time: "9:00" }];
  assert.equal(validateOptions(dup, APPT, NOW).ok, false);
  assert.equal(validateOptions([{ date: "21/10/2026", time: "11:00" }], APPT, NOW).ok, false);
  assert.equal(validateOptions([{ date: "20/10/2026", time: "12:00" }], APPT, NOW).ok, false); // 2h, falta antecedência
  assert.equal(validateOptions([{ date: "20/10/2026", time: "13:00" }], APPT, NOW).ok, true);  // exatamente 3h
  assert.equal(validateOptions([{ date: "20/10/2026", time: "08:00" }], APPT, NOW).ok, false); // passado
  assert.equal(validateOptions([{ date: "20/12/2026", time: "10:00" }], APPT, NOW).ok, false); // > 60 dias
});

test("prazo do tutor: 24h, mas nunca depois de 1h antes do 1º horário", () => {
  const far = parseDateTimeMs("25/10/2026", "10:00");      // muito depois
  assert.equal(computeDeadline(NOW, far), NOW + 24 * 3600 * 1000);
  const soon = parseDateTimeMs("20/10/2026", "16:00");      // 6h depois
  assert.equal(computeDeadline(NOW, soon), soon - 3600 * 1000);
  const edge = parseDateTimeMs("20/10/2026", "13:00");      // mínimo (3h): prazo = 2h
  assert.equal(computeDeadline(NOW, edge) - NOW, 2 * 3600 * 1000);
});

test("formatDeadline: dd/MM às HH:mm em Brasília", () => {
  assert.equal(formatDeadline(parseDateTimeMs("21/10/2026", "09:05")), "21/10 às 09:05");
});
