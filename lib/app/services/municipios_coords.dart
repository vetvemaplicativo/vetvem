import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import '../data/models/service_area_model.dart' show normalizeSearchText;

/// Centro geográfico de cada município (IBGE), embutido no app em
/// assets/data/municipios_coord.json — fonte: kelvins/municipios-brasileiros.
/// Formato de cada linha: [ibge, uf, nome, lat, lng].
///
/// Serve para a busca "perto de você": a distância é medida entre os centros
/// das cidades (não há coordenada de endereço nem de bairro no app).
class MunicipiosCoords {
  MunicipiosCoords._();

  static final Map<String, (double, double)> _byIbge = {};
  static final Map<String, String> _ibgeByName = {}; // "RJ|rio de janeiro" → ibge
  static final Map<String, List<(String, String)>> _byUf = {}; // UF → (ibge, nome)

  /// Municípios da UF em ordem alfabética (reserva quando a API do IBGE falha).
  static List<(String, String)> municipiosDaUf(String uf) =>
      _byUf[uf.trim().toUpperCase()] ?? const [];
  static Future<void>? _loading;

  static bool get isLoaded => _byIbge.isNotEmpty;

  static Future<void> ensureLoaded() =>
      _loading ??= _load().catchError((_) => _loading = null);

  static Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/data/municipios_coord.json');
    final list = jsonDecode(raw) as List;
    for (final row in list) {
      final r = row as List;
      final ibge = r[0].toString();
      _byIbge[ibge] = ((r[3] as num).toDouble(), (r[4] as num).toDouble());
      _ibgeByName['${r[1]}|${normalizeSearchText(r[2] as String)}'] = ibge;
      _byUf.putIfAbsent(r[1] as String, () => []).add((ibge, r[2] as String));
    }
    for (final l in _byUf.values) {
      l.sort((a, b) => a.$2.compareTo(b.$2));
    }
  }

  /// Código IBGE pela UF + nome (o endereço do tutor só guarda o nome).
  static String? ibgeOf(String uf, String cidade) =>
      _ibgeByName['${uf.trim().toUpperCase()}|${normalizeSearchText(cidade)}'];

  // Apelidos usados em endereços antigos, digitados à mão antes da busca
  // por CEP (ex.: "Rio" em vez de "Rio de Janeiro").
  static const _apelidos = {
    'rio': ('RJ', 'Rio de Janeiro'),
    'rj': ('RJ', 'Rio de Janeiro'),
    'rio de janeiro rj': ('RJ', 'Rio de Janeiro'),
    'sp': ('SP', 'São Paulo'),
    'sao paulo sp': ('SP', 'São Paulo'),
    'sampa': ('SP', 'São Paulo'),
    'bh': ('MG', 'Belo Horizonte'),
    'bhz': ('MG', 'Belo Horizonte'),
    'poa': ('RS', 'Porto Alegre'),
    'bsb': ('DF', 'Brasília'),
  };

  /// Nome oficial da cidade (e UF) a partir do que foi digitado no endereço.
  /// Aceita a UF vazia ou por extenso quando o nome da cidade é único no país,
  /// e apelidos comuns. Devolve null se não der para ter certeza.
  static (String uf, String cidade)? canonical(String uf, String cidade) {
    final ufN = uf.trim().toUpperCase();
    var nome = normalizeSearchText(cidade.replaceAll(RegExp(r'[/\-–,]'), ' '));
    nome = nome.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (nome.isEmpty) return null;
    final ap = _apelidos[nome];
    if (ap != null && (ufN.length != 2 || ufN == ap.$1)) return ap;
    if (ufN.length == 2) {
      final ibge = _ibgeByName['$ufN|$nome'];
      if (ibge != null) return (ufN, _nomeDe(ufN, ibge));
    }
    // UF ausente/por extenso: só aceita se o nome for único no Brasil.
    final hits = _ibgeByName.entries.where((e) => e.key.endsWith('|$nome'));
    if (hits.length == 1) {
      final u = hits.first.key.split('|').first;
      return (u, _nomeDe(u, hits.first.value));
    }
    return null;
  }

  static String _nomeDe(String uf, String ibge) =>
      (_byUf[uf] ?? const []).firstWhere((m) => m.$1 == ibge, orElse: () => (ibge, '')).$2;

  static (double, double)? coordOfIbge(String ibge) => _byIbge[ibge];

  /// Distância em km entre os centros de duas cidades (Haversine).
  static double? distanceKm(String ibgeA, String ibgeB) {
    final a = _byIbge[ibgeA], b = _byIbge[ibgeB];
    if (a == null || b == null) return null;
    if (ibgeA == ibgeB) return 0;
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(b.$1 - a.$1), dLng = rad(b.$2 - a.$2);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(a.$1)) * math.cos(rad(b.$1)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(h));
  }
}
