import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
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
      if (!authService.isLoggedIn) {
        Get.offAllNamed(Routes.login);
        return;
      }
      // Sessão persistida: garante o aceite dos termos antes da home
      final ok = await TermsView.ensureAccepted();
      Get.offAllNamed(ok ? Routes.home : Routes.login);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo_light.png',
              width: 180,
              height: 180,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            const Text(
              'VetVem',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Text(
              'Cuidado veterinario em casa',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
