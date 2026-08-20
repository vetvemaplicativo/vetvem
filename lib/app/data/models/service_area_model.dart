/// Área de atuação do profissional: Estado → Cidades → Bairros.
///
/// Persistida em `users/{uid}` em dois campos que DEVEM ser gravados juntos:
/// - `area_atuacao`: estrutura aninhada, usada para exibição
/// - `area_atuacao_keys`: lista achatada de chaves normalizadas, usada pelo
///   app do tutor para filtrar profissionais com `array-contains`
///   (o Firestore não consegue consultar dentro de arrays de objetos).
///
/// Formato das chaves:
/// - `UF|ibgeId` — nível cidade, sempre presente (filtro "quem atende nesta
///   cidade")
/// - `UF|ibgeId|bairro_normalizado` — um por bairro
/// - `UF|ibgeId|*` — quando o profissional atende a cidade toda
///
/// Filtro por bairro no app do tutor: `array-contains-any` com
/// `[UF|ibgeId|bairro, UF|ibgeId|*]`. A chave `*` é necessária porque a chave
/// de cidade existe para TODOS os profissionais — usá-la no filtro de bairro
/// retornaria qualquer profissional da cidade.
library;

const _accentMap = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};

/// Normaliza texto para chave de busca: minúsculas, sem acentos,
/// espaços múltiplos colapsados. Ex.: "  Icaraí " → "icarai".
String normalizeSearchText(String text) {
  var s = text.trim().toLowerCase();
  _accentMap.forEach((accented, plain) => s = s.replaceAll(accented, plain));
  return s.replaceAll(RegExp(r'\s+'), ' ');
}

class AreaCidade {
  final String nome;
  final String ibgeId;
  final bool atendeCidadeToda;

  /// Bairros como o profissional digitou (para exibição).
  final List<String> bairros;

  const AreaCidade({
    required this.nome,
    required this.ibgeId,
    this.atendeCidadeToda = false,
    this.bairros = const [],
  });

  AreaCidade copyWith({bool? atendeCidadeToda, List<String>? bairros}) {
    return AreaCidade(
      nome: nome,
      ibgeId: ibgeId,
      atendeCidadeToda: atendeCidadeToda ?? this.atendeCidadeToda,
      bairros: bairros ?? this.bairros,
    );
  }

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'ibge_id': ibgeId,
        'atende_cidade_toda': atendeCidadeToda,
        'bairros': bairros,
      };

  factory AreaCidade.fromMap(Map<String, dynamic> map) => AreaCidade(
        nome: map['nome'] ?? '',
        ibgeId: map['ibge_id']?.toString() ?? '',
        atendeCidadeToda: map['atende_cidade_toda'] == true,
        bairros: List<String>.from(map['bairros'] ?? []),
      );
}

class AreaAtuacao {
  /// Sigla da UF, ex.: "RJ".
  final String estado;
  final List<AreaCidade> cidades;

  const AreaAtuacao({required this.estado, this.cidades = const []});

  bool get isEmpty => estado.isEmpty || cidades.isEmpty;

  Map<String, dynamic> toMap() => {
        'estado': estado,
        'cidades': cidades.map((c) => c.toMap()).toList(),
      };

  factory AreaAtuacao.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AreaAtuacao(estado: '');
    return AreaAtuacao(
      estado: map['estado'] ?? '',
      cidades: List<Map<String, dynamic>>.from(map['cidades'] ?? [])
          .map(AreaCidade.fromMap)
          .toList(),
    );
  }

  /// Gera as chaves achatadas de busca (`area_atuacao_keys`).
  /// Única fonte de verdade do formato — nunca montar chaves manualmente.
  List<String> toSearchKeys() {
    final keys = <String>[];
    for (final cidade in cidades) {
      final cityKey = '$estado|${cidade.ibgeId}';
      keys.add(cityKey);
      if (cidade.atendeCidadeToda) {
        keys.add('$cityKey|*');
      } else {
        for (final bairro in cidade.bairros) {
          final normalized = normalizeSearchText(bairro);
          final key = '$cityKey|$normalized';
          if (normalized.isNotEmpty && !keys.contains(key)) keys.add(key);
        }
      }
    }
    return keys;
  }

  /// Verifica em memória se a área cobre o endereço dado. A cidade é
  /// comparada por nome normalizado porque o endereço do tutor não guarda
  /// código IBGE. Sem bairro informado, basta a cidade bater.
  bool cobreEndereco({
    required String uf,
    required String cidade,
    String bairro = '',
  }) {
    if (estado != uf.trim().toUpperCase()) return false;
    final cidadeNorm = normalizeSearchText(cidade);
    if (cidadeNorm.isEmpty) return false;
    final bairroNorm = normalizeSearchText(bairro);
    for (final c in cidades) {
      if (normalizeSearchText(c.nome) != cidadeNorm) continue;
      if (c.atendeCidadeToda || bairroNorm.isEmpty) return true;
      if (c.bairros.any((b) => normalizeSearchText(b) == bairroNorm)) {
        return true;
      }
    }
    return false;
  }

  /// Resumo legível, ex.: "Niterói (2 bairros) · Rio de Janeiro (cidade toda)".
  String get resumo => cidades.map((c) {
        final detalhe = c.atendeCidadeToda
            ? 'cidade toda'
            : '${c.bairros.length} bairro${c.bairros.length == 1 ? '' : 's'}';
        return '${c.nome} ($detalhe)';
      }).join(' · ');
}
