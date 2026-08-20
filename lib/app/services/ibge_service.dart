import 'dart:convert';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

class IbgeMunicipio {
  final String id;
  final String nome;

  const IbgeMunicipio({required this.id, required this.nome});

  Map<String, dynamic> toMap() => {'id': id, 'nome': nome};

  factory IbgeMunicipio.fromMap(Map<String, dynamic> map) =>
      IbgeMunicipio(id: map['id'].toString(), nome: map['nome'] ?? '');
}

/// Busca municípios por UF na API de localidades do IBGE, com cache
/// persistente — a malha municipal quase não muda, então o cache vale por
/// 30 dias e serve de fallback quando a rede falha.
class IbgeService extends GetxService {
  static const _baseUrl =
      'https://servicodados.ibge.gov.br/api/v1/localidades';
  static const _cacheBoxName = 'ibge_cache';
  static const _cacheTtl = Duration(days: 30);

  late final GetStorage _box;

  Future<IbgeService> init() async {
    await GetStorage.init(_cacheBoxName);
    _box = GetStorage(_cacheBoxName);
    return this;
  }

  Future<List<IbgeMunicipio>> getMunicipios(String uf) async {
    final cached = _readCache(uf, ignoreTtl: false);
    if (cached != null) return cached;

    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/estados/$uf/municipios'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw Exception('IBGE respondeu ${res.statusCode}');
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as List;
      final municipios = data
          .map((m) => IbgeMunicipio(
              id: m['id'].toString(), nome: m['nome'] ?? ''))
          .toList()
        ..sort((a, b) => a.nome.compareTo(b.nome));

      await _box.write('municipios_$uf', {
        'fetchedAt': DateTime.now().toIso8601String(),
        'items': municipios.map((m) => m.toMap()).toList(),
      });
      return municipios;
    } catch (_) {
      // Sem rede: cache vencido ainda é melhor que nada.
      final stale = _readCache(uf, ignoreTtl: true);
      if (stale != null) return stale;
      rethrow;
    }
  }

  List<IbgeMunicipio>? _readCache(String uf, {required bool ignoreTtl}) {
    final raw = _box.read<Map<String, dynamic>>('municipios_$uf');
    if (raw == null) return null;
    if (!ignoreTtl) {
      final fetchedAt = DateTime.tryParse(raw['fetchedAt'] ?? '');
      if (fetchedAt == null ||
          DateTime.now().difference(fetchedAt) > _cacheTtl) {
        return null;
      }
    }
    return List<Map<String, dynamic>>.from(raw['items'] ?? [])
        .map(IbgeMunicipio.fromMap)
        .toList();
  }
}
