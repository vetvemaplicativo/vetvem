import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../theme/vv2/vv2_tokens.dart';
import '../../../widgets/auth_widgets.dart';
import 'login_controller.dart';

/// Entrar ("Bem-vindo de volta"): e-mail, senha, recuperação de senha e
/// métodos sociais. Fluxos e regras vêm do [LoginController] existente.
class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Bem-vindo de volta!',
      petAsset: 'assets/images/tutor_entrar_pet.webp',
      petAspect: 372 / 680,
      children: [
        Text('Entre para agendar o veterinário do seu pet',
            style: Vv2.t(16, 24, 400, color: Vv2.textSecondary)),
        const SizedBox(height: 20),
        Form(
          key: controller.formKey,
          child: Column(
            children: [
              TextFormField(
                controller: controller.emailController,
                validator: controller.validateEmail,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                style: Vv2.t(16, 24, 400),
                decoration: authFieldDecoration(
                    'E-mail', Icons.mail_outline_rounded),
              ),
              const SizedBox(height: 14),
              Obx(() => TextFormField(
                    controller: controller.passwordController,
                    validator: controller.validatePassword,
                    obscureText: !controller.isPasswordVisible.value,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => controller.login(),
                    style: Vv2.t(16, 24, 400),
                    decoration: authFieldDecoration(
                      'Senha',
                      Icons.lock_outline_rounded,
                      suffix: IconButton(
                        tooltip: controller.isPasswordVisible.value
                            ? 'Ocultar senha'
                            : 'Mostrar senha',
                        icon: Icon(
                          controller.isPasswordVisible.value
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Vv2.textSecondary,
                        ),
                        onPressed: controller.togglePasswordVisibility,
                      ),
                    ),
                  )),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: controller.goToForgotPassword,
            style: TextButton.styleFrom(
                minimumSize: const Size(48, Vv2.tapMin)),
            child: Text('Esqueci minha senha',
                style: Vv2.t(14, 20, 700, color: Vv2.primary)),
          ),
        ),
        const SizedBox(height: 4),
        Obx(() => VvPillButton(
              label: 'Entrar',
              loading: controller.isLoading.value,
              onTap: controller.isLoading.value ? null : controller.login,
            )),
        const AuthOrDivider(),
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
        const SizedBox(height: 8),
        AuthTextLink('Não tem conta? Cadastre-se grátis',
            onTap: controller.goToRegister),
      ],
    );
  }
}
