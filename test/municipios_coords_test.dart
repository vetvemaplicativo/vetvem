import 'package:flutter_test/flutter_test.dart';
import 'package:vetvem/app/services/municipios_coords.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(MunicipiosCoords.ensureLoaded);

  test('acha a cidade pelo nome, com ou sem acento', () {
    expect(MunicipiosCoords.ibgeOf('RJ', 'Rio de Janeiro'), '3304557');
    expect(MunicipiosCoords.ibgeOf('rj', 'Niteroi'), '3303302');
    expect(MunicipiosCoords.ibgeOf('SP', 'Niterói'), isNull);
  });

  test('reconhece nomes antigos/curtos de cidade', () {
    expect(MunicipiosCoords.canonical('', 'Rio'), ('RJ', 'Rio de Janeiro'));
    expect(MunicipiosCoords.canonical('RJ', 'rio'), ('RJ', 'Rio de Janeiro'));
    expect(MunicipiosCoords.canonical('rj', 'niteroi'), ('RJ', 'Niterói'));
    expect(MunicipiosCoords.canonical('Rio de Janeiro', 'Maricá'), ('RJ', 'Maricá'));
    expect(MunicipiosCoords.canonical('', 'Rio de Janeiro/RJ'), ('RJ', 'Rio de Janeiro'));
    // nome repetido em vários estados sem UF: não arrisca
    expect(MunicipiosCoords.canonical('', 'Bom Jesus'), isNull);
  });

  test('Rio–Niterói dentro do raio, Rio–São Paulo fora', () {
    final rioNit = MunicipiosCoords.distanceKm('3304557', '3303302')!;
    final rioSp = MunicipiosCoords.distanceKm('3304557', '3550308')!;
    expect(rioNit, inInclusiveRange(5, 25));
    expect(rioSp, greaterThan(300));
    expect(MunicipiosCoords.distanceKm('3304557', '3304557'), 0);
  });
}
