// Cálculo do valor de um agendamento a partir do catálogo do profissional.
// Usado por createPayment/createPixPayment (ver computeAppointmentAmount em index.js).
//
// Regra: total = price + (n-1) × adicional, onde adicional = additionalPrice
// (se o profissional definiu) ou price. n = nº de animais do pedido.
//  - Serviço "por animal" (perAnimal === true): vale n, com o adicional que o
//    profissional configurou.
//  - Serviço comum: se o pedido declara vários animais (petCount/pets > 1, como
//    faz o portal para profissionais que não têm o cadastro "por animal"), cada
//    animal paga o preço cheio: n × price, sem desconto. Apps que só mandam
//    petCount em serviço "por animal" não são afetados.
// Teto de 50 animais (o app/portal limitam bem antes; é só um cinto de segurança).

const MAX_ANIMALS = 50;

function toNum(v) {
  return parseFloat(String(v === undefined || v === null ? "0" : v).replace(",", ".")) || 0;
}

// Nº de animais declarado no pedido (>= 1).
function animalsOf(appt) {
  const listed = Array.isArray(appt.pets) ? appt.pets.length : 0;
  const declared = parseInt(appt.petCount, 10) || 0;
  return Math.min(Math.max(declared, listed, 1), MAX_ANIMALS);
}

// svc: item de users/{vetId}.services; appt: documento do agendamento.
// Retorna { amount, count } ou null se o serviço não tem preço válido.
function priceForService(svc, appt) {
  const base = toNum(svc.price);
  if (!(base > 0)) return null;
  const n = animalsOf(appt);
  const count = svc.perAnimal === true || n > 1 ? n : 1;
  const extraRaw = svc.additionalPrice;
  // additionalPrice só vale em serviço "por animal"; no serviço comum o
  // animal extra paga o preço cheio.
  const extra =
    svc.perAnimal === true && extraRaw !== undefined && extraRaw !== null && String(extraRaw).trim() !== ""
      ? toNum(extraRaw)
      : base;
  const amount = Math.round((base + (count - 1) * extra) * 100) / 100;
  return { amount, count };
}

module.exports = { priceForService, animalsOf, toNum, MAX_ANIMALS };
