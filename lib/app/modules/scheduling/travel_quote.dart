import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

const _cfBase = 'https://southamerica-east1-vetvem-18bf4.cloudfunctions.net';

/// Cotação do deslocamento por km de um profissional até o endereço do tutor.
/// O valor sempre vem do servidor (que aplica os tetos do VetVem) e é o mesmo
/// que será cobrado no pagamento.
class TravelQuote {
  /// idle | loading | ok | out_of_range | no_cep | error
  final String state;
  final double fee;
  final double km;
  final bool roundTrip;
  final bool capped;
  final String message;

  const TravelQuote._(this.state,
      {this.fee = 0, this.km = 0, this.roundTrip = false, this.capped = false, this.message = ''});

  const TravelQuote.idle() : this._('idle');
  const TravelQuote.loading() : this._('loading');
  const TravelQuote.problem(String state, String message) : this._(state, message: message);
  const TravelQuote.ok(double fee, double km, bool roundTrip, bool capped)
      : this._('ok', fee: fee, km: km, roundTrip: roundTrip, capped: capped);

  bool get isOk => state == 'ok';
  bool get isLoading => state == 'loading';
}

Future<TravelQuote> fetchTravelQuote(String vetId, String cepDigits) async {
  try {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) {
      return const TravelQuote.problem('error', 'Entre na sua conta para continuar.');
    }
    final res = await http
        .post(
          Uri.parse('$_cfBase/travelQuote'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: jsonEncode({'vetId': vetId, 'cep': cepDigits}),
        )
        .timeout(const Duration(seconds: 25));
    final body = jsonDecode(res.body);
    if (res.statusCode == 200 && body is Map) {
      if (body['mode'] != 'per_km') return const TravelQuote.ok(0, 0, false, false);
      if (body['outOfRange'] == true) {
        return TravelQuote.problem('out_of_range',
            'Este profissional não atende o seu endereço (${body['km']} km, acima da distância máxima dele). Escolha outro endereço ou outro profissional.');
      }
      return TravelQuote.ok(
        (body['fee'] as num).toDouble(),
        (body['km'] as num).toDouble(),
        body['roundTrip'] == true,
        body['capped'] == true,
      );
    }
    final msg = (body is Map ? body['error'] : null)?.toString() ??
        'Não foi possível calcular o deslocamento.';
    final code = body is Map ? body['code']?.toString() : null;
    if (code == 'cep_invalido' || code == 'destino_nao_encontrado') {
      return TravelQuote.problem('no_cep', '$msg Confira o CEP do endereço no seu Perfil.');
    }
    return TravelQuote.problem('error', msg);
  } catch (_) {
    return const TravelQuote.problem(
        'error', 'Não foi possível calcular o deslocamento agora. Verifique a conexão e tente de novo.');
  }
}
