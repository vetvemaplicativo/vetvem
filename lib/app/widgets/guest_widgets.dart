import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../routes/app_routes.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Pede conta ao visitante que tentou agendar. Guarda o profissional escolhido
/// para a Home retomar o agendamento depois do login/cadastro.
Future<void> showGuestWall({required String vetId}) async {
  final auth = Get.find<AuthService>();
  final analytics = Get.find<AnalyticsService>();
  analytics.logWallShown('agendar', vetId);
  final action = await Get.bottomSheet<String>(
    const _GuestWallSheet(),
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
  );
  if (action == 'register') {
    analytics.logWallAction('criar_conta');
    auth.pendingVetId = vetId;
    Get.toNamed(Routes.register);
  } else if (action == 'login') {
    analytics.logWallAction('entrar');
    auth.pendingVetId = vetId;
    Get.toNamed(Routes.login);
  } else {
    analytics.logWallAction('dispensou');
  }
}

class _GuestWallSheet extends StatelessWidget {
  const _GuestWallSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Crie sua conta para agendar',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'É rápido: com a conta você acompanha o pedido, conversa com o '
              'profissional e recebe o prontuário do seu pet.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textMedium,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: () => Get.back(result: 'register'),
              child: const Text('Criar conta'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Get.back(result: 'login'),
              child: const Text('Já tenho conta'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tela das abas que dependem de conta (Consultas, Perfil) para o visitante.
class GuestGate extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const GuestGate({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 34),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textMedium,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Get.toNamed(Routes.register),
                  child: const Text('Criar conta'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Get.toNamed(Routes.login),
                  child: const Text('Já tenho conta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
