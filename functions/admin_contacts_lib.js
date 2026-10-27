// Junta as fontes de contato na ordem: cadastro (users) > login (Auth) > pedido.
function pickContact(user, authUser, appt) {
  const phone = String((user && user.phone) || (authUser && authUser.phoneNumber) || (appt && appt.phone) || "").trim();
  const email = String((user && user.email) || (authUser && authUser.email) || (appt && appt.email) || "").trim();
  return { phone, email };
}

module.exports = { pickContact };
