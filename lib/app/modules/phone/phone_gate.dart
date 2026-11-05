import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_theme.dart';
import '../../utils/input_formatters.dart';

/// Gate do login: o celular (WhatsApp) é obrigatório. Cadastro por e-mail já pede;
/// contas criadas com Google/Apple e contas antigas passam por aqui e só seguem
/// depois de informar o número.
class PhoneGate extends StatefulWidget {
  const PhoneGate({super.key});

  static bool _valid(dynamic phone) =>
      phone is String && phone.replaceAll(RegExp(r'\D'), '').length >= 10;

  /// Retorna true se a conta já tem celular (ou se acabou de informar).
  /// Retorna false se a pessoa preferiu sair.
  static Future<bool> ensure() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (_valid(doc.data()?['phone'])) return true;
    } catch (_) {
      return true; // sem rede: não bloqueia; o gate roda de novo no próximo acesso
    }
    return await Get.to<bool>(() => const PhoneGate(), fullscreenDialog: true) ??
        false;
  }

  @override
  State<PhoneGate> createState() => _PhoneGateState();
}

class _PhoneGateState extends State<PhoneGate> {
  final _ctrl = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'phone': _ctrl.text.trim()}, SetOptions(merge: true));
      Get.back(result: true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Não foi possível salvar. Verifique a internet e tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.phone_iphone_rounded,
                      size: 48, color: AppColors.primary),
                  const SizedBox(height: 20),
                  const Text('Qual é o seu celular?',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Usamos seu número (WhatsApp) para avisar sobre o agendamento '
                    'e falar com você se algo mudar na consulta.',
                    style: TextStyle(fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _ctrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [PhoneInputFormatter()],
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'Celular (WhatsApp)'),
                    validator: (v) {
                      final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
                      if (d.isEmpty) return 'Informe seu celular';
                      if (d.length < 10) return 'Número inválido';
                      return null;
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Salvando…' : 'Continuar'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _saving ? null : () => Get.back(result: false),
                      child: const Text('Sair da conta'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
