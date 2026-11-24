import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../routes/app_routes.dart';
import '../../theme/vv2/vv2_tokens.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../phone/phone_gate.dart';
import '../terms/terms_view.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () async {
      final authService = Get.find<AuthService>();
      final fbUser = FirebaseAuth.instance.currentUser;
      // Visitante (login anônimo) já existente: segue direto para a Home.
      if (fbUser != null && fbUser.isAnonymous) {
        if (await _guestModeEnabled()) {
          Get.offAllNamed(Routes.home);
        } else {
          await authService.signOut();
          Get.offAllNamed(Routes.login);
        }
        return;
      }
      if (fbUser == null) {
        // Primeira abertura: deixa explorar antes de criar conta. Qualquer falha
        // (sem rede, interruptor desligado) cai no login de sempre.
        if (await authService.startGuestSession()) {
          if (await _guestModeEnabled()) {
            Get.find<AnalyticsService>().logGuestStart();
            Get.offAllNamed(Routes.home);
            return;
          }
          await authService.signOut();
        }
        Get.offAllNamed(Routes.login);
        return;
      }
      // Sessão persistida: garante o aceite dos termos antes da home
      var ok = await TermsView.ensureAccepted();
      // Celular (WhatsApp) obrigatório: pede a contas sem telefone (Google/Apple/antigas)
      if (ok) ok = await PhoneGate.ensure();
      if (!ok) await authService.signOut();
      Get.offAllNamed(ok ? Routes.home : Routes.login);
    });
  }

  /// Interruptor remoto: config/tutor_flags.guestMode == false desliga o modo
  /// visitante sem precisar de nova versão. Ausente/erro = ligado.
  Future<bool> _guestModeEnabled() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('tutor_flags')
          .get()
          .timeout(const Duration(seconds: 4));
      return doc.data()?['guestMode'] != false;
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    // Pets em escala proporcional à largura; cortados nas laterais, com rosto e
    // orelhas visíveis. Decorativos (sem semântica).
    final catW = w * 0.50;
    final dogW = w * 0.63;
    return Scaffold(
      // Mesma cor do logo (o PNG tem cantos transparentes): com AppColors.primary
      // o quadrado do logo aparecia como um bloco de tom diferente no fundo.
      backgroundColor: const Color(0xFFFF590E),
      body: Stack(
        children: [
          Positioned(
            left: -w * 0.06,
            bottom: 0,
            width: catW,
            child: Image.asset('assets/images/tutor_splash_gato_esquerda.webp',
                fit: BoxFit.contain, excludeFromSemantics: true),
          ),
          Positioned(
            right: -w * 0.03,
            bottom: 0,
            width: dogW,
            child: Image.asset(
                'assets/images/tutor_splash_cachorro_direita.webp',
                fit: BoxFit.contain,
                excludeFromSemantics: true),
          ),
          Align(
            alignment: const Alignment(0, -0.42),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo_light.png',
                  width: 112,
                  height: 112,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                Text('VetVem', style: Vv2.t(36, 44, 700, color: Colors.white)),
                const SizedBox(height: 4),
                Text('Cuidado veterinário em casa',
                    style: Vv2.t(16, 24, 500, color: Vv2.onBrand)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
