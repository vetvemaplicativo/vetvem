import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';

const _cfBase = 'https://southamerica-east1-vetvem-18bf4.cloudfunctions.net';
const _secondaryAppName = 'portal_claim';

/// Traz para a conta do app as consultas CONCLUÍDAS feitas pelo site (portal).
/// O portal identifica o cliente pelo celular (SMS), então aqui o celular é confirmado de novo
/// num app Firebase secundário (para não trocar o login do app) e o servidor recebe os dois
/// tokens: o da conta do app e o do celular. Ver functions/claim_portal.js.
class ClaimPortalService {
  static Future<FirebaseAuth> _secondaryAuth() async {
    FirebaseApp app;
    try {
      app = Firebase.app(_secondaryAppName);
    } catch (_) {
      app = await Firebase.initializeApp(name: _secondaryAppName, options: Firebase.app().options);
    }
    return FirebaseAuth.instanceFor(app: app);
  }

  /// Envia o SMS. Retorna o verificationId; [onAutoCredential] é chamado se o Android ler o SMS sozinho.
  static Future<String> sendCode(String phoneE164, {required void Function(PhoneAuthCredential) onAutoCredential}) async {
    final auth = await _secondaryAuth();
    final done = Completer<String>();
    await auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      timeout: const Duration(seconds: 60),
      verificationCompleted: onAutoCredential,
      verificationFailed: (e) {
        if (!done.isCompleted) done.completeError(e);
      },
      codeSent: (id, _) {
        if (!done.isCompleted) done.complete(id);
      },
      codeAutoRetrievalTimeout: (id) {
        if (!done.isCompleted) done.complete(id);
      },
    );
    return done.future;
  }

  /// Confirma o celular com [credential], chama o servidor e devolve quantas consultas foram trazidas.
  static Future<int> claim(PhoneAuthCredential credential) async {
    final main = FirebaseAuth.instance.currentUser;
    if (main == null) throw Exception('Faça login novamente.');
    final secondary = await _secondaryAuth();
    try {
      final cred = await secondary.signInWithCredential(credential);
      final phoneToken = await cred.user?.getIdToken(true);
      final appToken = await main.getIdToken(true);
      if (phoneToken == null || appToken == null) throw Exception('Não foi possível confirmar o celular.');
      final res = await http
          .post(
            Uri.parse('$_cfBase/claimPortalAppointments'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $appToken'},
            body: jsonEncode({'phoneIdToken': phoneToken}),
          )
          .timeout(const Duration(seconds: 30));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['ok'] == true) return (body['moved'] as num?)?.toInt() ?? 0;
      throw Exception((body['error'] ?? 'Não foi possível trazer as consultas agora.').toString());
    } finally {
      try {
        await secondary.signOut();
      } catch (_) {}
    }
  }
}

/// Abre o fluxo em uma folha inferior.
Future<void> showClaimPortalSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ClaimSheet(),
  );
}

/// Cartão que convida a trazer as consultas do site.
class ClaimPortalCard extends StatelessWidget {
  const ClaimPortalCard({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showClaimPortalSheet(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.history, color: AppColors.primary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Já agendou pelo nosso site? Traga suas consultas para cá.',
                style: TextStyle(fontSize: 13, color: AppColors.textMedium, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.primary.withValues(alpha: 0.8)),
          ],
        ),
      ),
    );
  }
}

enum _Step { phone, code, working, done }

class _ClaimSheet extends StatefulWidget {
  const _ClaimSheet();

  @override
  State<_ClaimSheet> createState() => _ClaimSheetState();
}

class _ClaimSheetState extends State<_ClaimSheet> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  _Step _step = _Step.phone;
  String _verificationId = '';
  String? _error;
  bool _sending = false;
  int _moved = 0;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  String? _e164() {
    final d = _phone.text.replaceAll(RegExp(r'\D'), '');
    final local = d.startsWith('55') && d.length > 11 ? d.substring(2) : d;
    if (local.length != 10 && local.length != 11) return null;
    return '+55$local';
  }

  String _friendly(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-phone-number':
          return 'Número de celular inválido.';
        case 'too-many-requests':
          return 'Muitas tentativas. Aguarde alguns minutos e tente de novo.';
        case 'invalid-verification-code':
          return 'Código incorreto. Confira o SMS.';
        case 'session-expired':
        case 'code-expired':
          return 'O código expirou. Peça um novo.';
        case 'network-request-failed':
          return 'Sem conexão. Verifique a internet.';
      }
      return 'Não foi possível confirmar o celular. Tente novamente.';
    }
    final m = e.toString().replaceFirst('Exception: ', '');
    return m.isEmpty ? 'Não foi possível concluir. Tente novamente.' : m;
  }

  Future<void> _send() async {
    final phone = _e164();
    if (phone == null) {
      setState(() => _error = 'Informe o celular com DDD.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final id = await ClaimPortalService.sendCode(phone, onAutoCredential: (cred) {
        if (mounted && _step == _Step.code) _finish(cred);
      });
      if (!mounted) return;
      setState(() {
        _verificationId = id;
        _step = _Step.code;
        _sending = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _friendly(e);
          _sending = false;
        });
      }
    }
  }

  Future<void> _confirm() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Digite os 6 números do SMS.');
      return;
    }
    await _finish(PhoneAuthProvider.credential(verificationId: _verificationId, smsCode: code));
  }

  Future<void> _finish(PhoneAuthCredential cred) async {
    setState(() {
      _step = _Step.working;
      _error = null;
    });
    try {
      final n = await ClaimPortalService.claim(cred);
      if (!mounted) return;
      setState(() {
        _moved = n;
        _step = _Step.done;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _friendly(e);
          _step = _Step.code;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: _content()),
      ),
    );
  }

  List<Widget> _content() {
    const title = TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark);
    const body = TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.4);
    Widget button(String label, VoidCallback? onTap) => SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(label),
          ),
        );
    final err = _error == null
        ? <Widget>[]
        : [const SizedBox(height: 10), Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red))];

    switch (_step) {
      case _Step.phone:
        return [
          const Text('Trazer consultas do site', style: title),
          const SizedBox(height: 8),
          const Text(
            'Informe o celular que você usou para agendar pelo site. Vamos enviar um SMS para confirmar que ele é seu. '
            'Só as consultas já concluídas, com o prontuário, vêm para o app.',
            style: body,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9()\-\s+]'))],
            decoration: const InputDecoration(labelText: 'Celular com DDD', hintText: '(11) 91234-5678', border: OutlineInputBorder()),
          ),
          ...err,
          const SizedBox(height: 14),
          button(_sending ? 'Enviando…' : 'Enviar código por SMS', _sending ? null : _send),
        ];
      case _Step.code:
        return [
          const Text('Digite o código', style: title),
          const SizedBox(height: 8),
          Text('Enviamos um SMS para ${_phone.text.trim()}.', style: body),
          const SizedBox(height: 14),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Código de 6 números', border: OutlineInputBorder(), counterText: ''),
          ),
          ...err,
          const SizedBox(height: 14),
          button('Confirmar e trazer consultas', _confirm),
          TextButton(
            onPressed: () => setState(() {
              _step = _Step.phone;
              _error = null;
              _code.clear();
            }),
            child: const Text('Trocar o número'),
          ),
        ];
      case _Step.working:
        return const [
          SizedBox(height: 24),
          Center(child: CircularProgressIndicator(color: AppColors.primary)),
          SizedBox(height: 16),
          Center(child: Text('Trazendo as suas consultas…', style: TextStyle(fontSize: 13, color: AppColors.textMedium))),
          SizedBox(height: 24),
        ];
      case _Step.done:
        return [
          Text(_moved > 0 ? 'Pronto! 🐾' : 'Nada por aqui', style: title),
          const SizedBox(height: 8),
          Text(
            _moved > 0
                ? (_moved == 1
                    ? 'Trouxemos 1 consulta para a sua conta. Ela já aparece em Minhas Consultas.'
                    : 'Trouxemos $_moved consultas para a sua conta. Elas já aparecem em Minhas Consultas.')
                : 'Não encontramos consultas concluídas para esse celular. Confira se é o mesmo número usado no agendamento pelo site. '
                    'Consultas ainda não concluídas continuam sendo acompanhadas por e-mail.',
            style: body,
          ),
          const SizedBox(height: 16),
          button('Fechar', () => Navigator.of(context).pop()),
        ];
    }
  }
}
