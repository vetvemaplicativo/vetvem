import 'package:flutter_test/flutter_test.dart';
import 'package:vetvem/app/data/models/service_area_model.dart';

void main() {
  group('normalizeSearchText', () {
    test('remove acentos, caixa e espaços extras', () {
      expect(normalizeSearchText('  Icaraí '), 'icarai');
      expect(normalizeSearchText('SÃO   FRANCISCO'), 'sao francisco');
      expect(normalizeSearchText('Jardim Botânico'), 'jardim botanico');
    });
  });

  group('AreaAtuacao.toSearchKeys', () {
    test('gera chave de cidade + chaves de bairro normalizadas', () {
      const area = AreaAtuacao(
        estado: 'RJ',
        cidades: [
          AreaCidade(
            nome: 'Niterói',
            ibgeId: '3303302',
            bairros: ['Icaraí', 'São Francisco'],
          ),
        ],
      );
      expect(area.toSearchKeys(), [
        'RJ|3303302',
        'RJ|3303302|icarai',
        'RJ|3303302|sao francisco',
      ]);
    });

    test('cidade toda gera chave de cidade + chave curinga', () {
      const area = AreaAtuacao(
        estado: 'RJ',
        cidades: [
          AreaCidade(
            nome: 'Rio de Janeiro',
            ibgeId: '3304557',
            atendeCidadeToda: true,
            bairros: ['Botafogo'], // ignorados quando atende a cidade toda
          ),
        ],
      );
      expect(area.toSearchKeys(), ['RJ|3304557', 'RJ|3304557|*']);
    });

    test('bairros duplicados após normalização não geram chave repetida', () {
      const area = AreaAtuacao(
        estado: 'RJ',
        cidades: [
          AreaCidade(
            nome: 'Niterói',
            ibgeId: '3303302',
            bairros: ['Icaraí', 'icarai'],
          ),
        ],
      );
      expect(area.toSearchKeys(), ['RJ|3303302', 'RJ|3303302|icarai']);
    });

    test('cobreEndereco casa bairro, cidade toda e rejeita fora da área', () {
      const area = AreaAtuacao(
        estado: 'RJ',
        cidades: [
          AreaCidade(
            nome: 'Niterói',
            ibgeId: '3303302',
            bairros: ['Icaraí'],
          ),
          AreaCidade(
            nome: 'Rio de Janeiro',
            ibgeId: '3304557',
            atendeCidadeToda: true,
          ),
        ],
      );
      // Bairro atendido (com variação de acento/caixa)
      expect(
          area.cobreEndereco(uf: 'RJ', cidade: 'niteroi', bairro: 'ICARAI'),
          isTrue);
      // Bairro não atendido na cidade
      expect(
          area.cobreEndereco(uf: 'RJ', cidade: 'Niterói', bairro: 'Centro'),
          isFalse);
      // Cidade toda cobre qualquer bairro
      expect(
          area.cobreEndereco(
              uf: 'RJ', cidade: 'Rio de Janeiro', bairro: 'Bangu'),
          isTrue);
      // Sem bairro informado, cidade basta
      expect(area.cobreEndereco(uf: 'RJ', cidade: 'Niterói'), isTrue);
      // UF errada
      expect(
          area.cobreEndereco(uf: 'SP', cidade: 'Niterói', bairro: 'Icaraí'),
          isFalse);
    });

    test('roundtrip toMap/fromMap preserva os dados', () {
      const area = AreaAtuacao(
        estado: 'RJ',
        cidades: [
          AreaCidade(nome: 'Niterói', ibgeId: '3303302', bairros: ['Icaraí']),
        ],
      );
      final restored = AreaAtuacao.fromMap(area.toMap());
      expect(restored.estado, 'RJ');
      expect(restored.cidades.length, 1);
      expect(restored.cidades.first.nome, 'Niterói');
      expect(restored.cidades.first.ibgeId, '3303302');
      expect(restored.cidades.first.bairros, ['Icaraí']);
      expect(restored.toSearchKeys(), area.toSearchKeys());
    });
  });
}
