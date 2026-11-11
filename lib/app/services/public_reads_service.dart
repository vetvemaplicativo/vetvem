import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

const _cfBase = 'https://southamerica-east1-vetvem-18bf4.cloudfunctions.net';

/// Leituras que antes iam direto em `appointments` e agora passam pelo servidor
/// (a coleção deixa de ser legível por qualquer login).
class PublicReadsService {
  static Future<Map<String, dynamic>> _post(String fn, Map<String, dynamic> data) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw Exception('sem login');
    final res = await http
        .post(
          Uri.parse('$_cfBase/$fn'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('$fn: ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Horários ocupados do profissional em [date] (dd/mm/aaaa).
  static Future<Set<String>> busyTimes({required String vetId, required String vetName, required String date}) async {
    final r = await _post('busyTimes', {'vetId': vetId, 'vetName': vetName, 'date': date});
    return (r['times'] as List? ?? const []).map((e) => e.toString()).toSet();
  }

  /// Avaliações do profissional: { reviews: [...], rating, reviewCount }.
  static Future<Map<String, dynamic>> vetReviews({required String vetId, required String vetName}) =>
      _post('vetReviews', {'vetId': vetId, 'vetName': vetName});
}
