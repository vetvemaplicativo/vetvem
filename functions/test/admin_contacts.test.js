const test = require("node:test");
const assert = require("node:assert");
const { pickContact } = require("../admin_contacts_lib");

test("pickContact: cadastro vence login e pedido", () => {
  assert.deepEqual(pickContact({ phone: "21999990000", email: "a@a.com" }, { phoneNumber: "+5511" }, { email: "x" }),
    { phone: "21999990000", email: "a@a.com" });
});
test("pickContact: portal usa o telefone do login (Auth) e o e-mail do pedido", () => {
  assert.deepEqual(pickContact(null, { phoneNumber: "+5521988887777" }, { email: "t@t.com" }),
    { phone: "+5521988887777", email: "t@t.com" });
});
test("pickContact: sem nada devolve vazio", () => {
  assert.deepEqual(pickContact(null, null, null), { phone: "", email: "" });
});
