import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../theme/vv2/vv2_tokens.dart';
import '../../../widgets/auth_widgets.dart';
import 'create_account_controller.dart';

/// Criar conta: escolha do método (Google, Apple no iPhone ou e-mail).
class CreateAccountView extends GetView<CreateAccountController> {
  const CreateAccountView({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Criar conta',
      petAsset: 'assets/images/tutor_criar_conta_pet.webp',
      petAspect: 500 / 599,
      petShift: 28,
      children: [
        Text('Escolha como criar sua conta',
            style: Vv2.t(16, 24, 400, color: Vv2.textSecondary)),
        const SizedBox(height: 20),
        Obx(() => VvPillButton(
              label: 'Continuar com Google',
              kind: VvPillKind.outlined,
              leading: const GoogleLogo(),
              onTap:
                  controller.isLoading.value ? null : controller.loginWithGoogle,
            )),
        if (Platform.isIOS) ...[
          const SizedBox(height: 12),
          Obx(() => VvPillButton(
                label: 'Continuar com Apple',
                kind: VvPillKind.black,
                leading:
                    const Icon(Icons.apple, color: Colors.white, size: 22),
                onTap:
                    controller.isLoading.value ? null : controller.loginWithApple,
              )),
        ],
        const AuthOrDivider(),
        Obx(() => VvPillButton(
              label: 'Cadastrar com e-mail',
              onTap: controller.isLoading.value ? null : controller.goToEmail,
            )),
        const SizedBox(height: 8),
        AuthTextLink('Já tenho conta', onTap: controller.goToLogin),
      ],
    );
  }
}
