import 'package:flutter_test/flutter_test.dart';
import 'package:vetvem/app/data/models/vet_model.dart';

// Mesma regra do servidor (functions/appointment_amount.js) e do portal (pricing.ts).
void main() {
  VetService svc(double price, {bool perAnimal = false, double? extra}) => VetService(
        name: 'Vacina',
        description: '',
        price: price,
        unit: 'dose',
        perAnimal: perAnimal,
        additionalPrice: extra,
      );

  test('1 animal: preço do serviço, qualquer tipo', () {
    expect(svc(80).totalFor(1), 80);
    expect(svc(80, perAnimal: true, extra: 50).totalFor(1), 80);
  });

  test('serviço comum (profissional antigo): preço cheio x animais — 2 x R\$ 80 = R\$ 160', () {
    expect(svc(80).totalFor(2), 160);
    expect(svc(80).totalFor(6), 480);
    expect(svc(80.5).totalFor(3), 241.5);
    // adicional configurado não vale em serviço comum
    expect(svc(80, extra: 10).totalFor(2), 160);
  });

  test('serviço por animal: usa o adicional ou o preço cheio', () {
    expect(svc(80, perAnimal: true, extra: 60).totalFor(3), 200);
    expect(svc(80, perAnimal: true).totalFor(3), 240);
  });

  test('arredonda em centavos', () {
    expect(svc(33.33).totalFor(3), 99.99);
  });
}
