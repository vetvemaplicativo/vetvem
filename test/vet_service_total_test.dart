import 'package:flutter_test/flutter_test.dart';
import 'package:vetvem/app/data/models/vet_model.dart';

// Mesma regra do servidor (functions/appointment_amount.js) e do portal (pricing.ts).
void main() {
  taxaDeDeslocamento();
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

void taxaDeDeslocamento() {
  group('taxa de deslocamento', () {
    test('fixa por visita: soma uma vez, independente do número de animais', () {
      const s = VetService(
          name: 'Ultrassom', description: '', price: 200, unit: 'consulta', travelFee: 80);
      expect(s.travel, 80);
      expect(s.grandTotalFor(1), 280);
      expect(s.grandTotalFor(3), 200 * 3 + 80); // comum: preço cheio x n + 1 taxa
    });
    test('com desconto nos adicionais + taxa', () {
      const s = VetService(
          name: 'Vacina', description: '', price: 80, unit: 'dose',
          perAnimal: true, additionalPrice: 60, travelFee: 50);
      expect(s.grandTotalFor(3), 80 + 2 * 60 + 50);
    });
    test('sem taxa ou taxa zero não altera o total', () {
      const a = VetService(name: 'x', description: '', price: 100, unit: 'consulta');
      const b = VetService(name: 'x', description: '', price: 100, unit: 'consulta', travelFee: 0);
      expect(a.grandTotalFor(2), 200);
      expect(b.grandTotalFor(2), 200);
      expect(a.travel, 0);
    });
  });
}
