import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../routes/app_routes.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/vv2/vv2_icon.dart';
import '../theme/vv2/vv2_tokens.dart';

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
        color: Vv2.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Vv2.rOverlay)),
      ),
      padding: const EdgeInsets.fromLTRB(Vv2.gutter, 12, Vv2.gutter, 12),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Vv2.brand,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Crie sua conta para agendar', style: Vv2.titleLarge),
              const SizedBox(height: 8),
              Text(
                'É rápido: com a conta você acompanha o pedido, conversa com o '
                'profissional e recebe o prontuário do seu pet.',
                style: Vv2.bodyMedium,
              ),
              const SizedBox(height: 20),
              Semantics(
                button: true,
                label: 'Criar conta',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => Get.back(result: 'register'),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.fromLTRB(24, 6, 6, 6),
                    decoration: BoxDecoration(
                      gradient: Vv2.ctaGradient,
                      borderRadius: BorderRadius.circular(Vv2.rPill),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Criar conta',
                              textAlign: TextAlign.center,
                              style: Vv2.t(17, 24, 700, color: Vv2.onBrand)),
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Vv2.surface.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                          child: const Vv2Icon(Ph.caretRight,
                              size: 20, color: Vv2.onBrand),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Get.back(result: 'login'),
                style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(Vv2.tapMin)),
                child: Text('Já tenho conta',
                    style: Vv2.t(15, 20, 700, color: Vv2.primary)),
              ),
            ],
          ),
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
