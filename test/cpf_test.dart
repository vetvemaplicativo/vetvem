import 'package:flutter_test/flutter_test.dart';
import 'package:vetvem/app/utils/cpf.dart';

void main() {
  test('CPFs válidos (com e sem máscara)', () {
    expect(isValidCpf('529.982.247-25'), isTrue);
    expect(isValidCpf('52998224725'), isTrue);
    expect(isValidCpf('111.444.777-35'), isTrue);
  });
  test('CPFs inválidos', () {
    expect(isValidCpf(null), isFalse);
    expect(isValidCpf(''), isFalse);
    expect(isValidCpf('529.982.247-24'), isFalse); // dígito errado
    expect(isValidCpf('123.456.789-00'), isFalse);
    expect(isValidCpf('111.111.111-11'), isFalse); // repetidos
    expect(isValidCpf('000.000.000-00'), isFalse);
    expect(isValidCpf('529.982.247-2'), isFalse); // curto
  });
}
