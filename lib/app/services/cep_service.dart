import 'dart:convert';

import 'package:http/http.dart' as http;

/// Resultado da busca de CEP, já no formato dos campos de endereço.
class CepResult {
  final String street;
  final String neighborhood;
  final String city;
  final String state; // sigla, ex.: RJ

  const CepResult({
    required this.street,
    required this.neighborhood,
    required this.city,
    required this.state,
  });
}

/// Busca CEP com timeout e fallback: ViaCEP → BrasilAPI.
/// Retorna null se o CEP não existir ou ambos os serviços falharem.
Future<CepResult?> lookupCep(String cep) async {
  final digits = cep.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 8) return null;

  // 1ª tentativa: ViaCEP
  try {
    final res = await http
        .get(Uri.parse('https://viacep.com.br/ws/$digits/json/'))
        .timeout(const Duration(seconds: 6));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['erro'] != true) {
        return CepResult(
          street: data['logradouro'] ?? '',
          neighborhood: data['bairro'] ?? '',
          city: data['localidade'] ?? '',
          state: data['uf'] ?? '',
        );
      }
      return null; // CEP inexistente
    }
  } catch (_) {
    // cai para o fallback
  }

  // 2ª tentativa: BrasilAPI
  try {
    final res = await http
        .get(Uri.parse('https://brasilapi.com.br/api/cep/v1/$digits'))
        .timeout(const Duration(seconds: 6));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return CepResult(
        street: data['street'] ?? '',
        neighborhood: data['neighborhood'] ?? '',
        city: data['city'] ?? '',
        state: data['state'] ?? '',
      );
    }
    if (res.statusCode == 404) return null; // CEP inexistente
  } catch (_) {}

  throw Exception('offline'); // ambos falharam: problema de rede
}
