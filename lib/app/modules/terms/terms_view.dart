import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_theme.dart';
import 'terms_content.dart';

/// Tela de Termos de Uso.
/// - readOnly: consulta pelo perfil (sem checkbox/botões)
/// - onAccept: chamado após o aceite (o registro no Firestore é feito por
///   [TermsView.recordAcceptance], chame-a no fluxo apropriado)
class TermsView extends StatefulWidget {
  final bool readOnly;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const TermsView({
    super.key,
    this.readOnly = false,
    this.onAccept,
    this.onDecline,
  });

  /// Grava o aceite no doc do usuário logado (merge — serve para doc novo ou
  /// conta antiga passando pelo gate do login).
  static Future<void> recordAcceptance() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'termos_aceitos': true,
      'termos_aceitos_em': FieldValue.serverTimestamp(),
      'termos_versao': termsVersion,
    }, SetOptions(merge: true));
  }

  /// Gate do login: se a conta ainda não aceitou os termos, mostra a tela.
  /// Retorna true se o acesso pode prosseguir.
  static Future<bool> ensureAccepted() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.data()?['termos_aceitos'] == true) return true;
    } catch (_) {
      return true; // sem rede: não bloqueia; o gate roda de novo no próximo login
    }
    final accepted = await Get.to<bool>(
          () => TermsView(
            onAccept: () => Get.back(result: true),
            onDecline: () => Get.back(result: false),
          ),
          fullscreenDialog: true,
        ) ??
        false;
    if (accepted) await recordAcceptance();
    return accepted;
  }

  @override
  State<TermsView> createState() => _TermsViewState();
}

class _TermsViewState extends State<TermsView> {
  final _scroll = ScrollController();
  bool _reachedEnd = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_reachedEnd &&
          _scroll.position.pixels >=
              _scroll.position.maxScrollExtent - 24) {
        setState(() => _reachedEnd = true);
      }
    });
    // Texto menor que a tela: libera direto
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.position.maxScrollExtent <= 0) {
        setState(() => _reachedEnd = true);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Termos de Uso',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
        automaticallyImplyLeading: widget.readOnly,
      ),
      body: Column(
        children: [
          Expanded(
            child: Scrollbar(
              controller: _scroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.all(20),
                child: Text(
                  termsText,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppColors.textDark,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
          ),
          if (!widget.readOnly)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -4))
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_reachedEnd)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Role até o final do texto para habilitar o aceite',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMedium,
                              fontFamily: 'Poppins'),
                        ),
                      ),
                    Row(
                      children: [
                        Checkbox(
                          value: _checked,
                          activeColor: AppColors.primary,
                          onChanged: _reachedEnd
                              ? (v) => setState(() => _checked = v ?? false)
                              : null,
                        ),
                        const Expanded(
                          child: Text(
                            'Li e aceito os Termos de Uso e a Política de Privacidade',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textDark,
                                fontFamily: 'Poppins'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _checked ? widget.onAccept : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: const Color(0xFFE5E7EB),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Concordar e continuar',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins')),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onDecline ?? () => Get.back(),
                      child: const Text('Recusar',
                          style: TextStyle(
                              color: AppColors.textMedium,
                              fontFamily: 'Poppins')),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
