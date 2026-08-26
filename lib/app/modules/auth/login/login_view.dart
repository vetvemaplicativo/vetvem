import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../theme/app_theme.dart';
import 'login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                Center(
                  child: Image.asset(
                    'assets/images/logo_dark.png',
                    height: 64,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Bem-vindo de volta!',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Entre para agendar o veterinário do seu pet',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: controller.emailController,
                  validator: controller.validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'E-mail',
                    prefixIcon: Icon(Icons.email_outlined, color: AppColors.textLight),
                  ),
                ),
                const SizedBox(height: 16),
                Obx(() => TextFormField(
                      controller: controller.passwordController,
                      validator: controller.validatePassword,
                      obscureText: !controller.isPasswordVisible.value,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => controller.login(),
                      decoration: InputDecoration(
                        hintText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textLight),
                        suffixIcon: IconButton(
                          icon: Icon(
                            controller.isPasswordVisible.value
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textLight,
                          ),
                          onPressed: controller.togglePasswordVisibility,
                        ),
                      ),
                    )),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: controller.goToForgotPassword,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Esqueci minha senha',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Obx(() => ElevatedButton(
                      onPressed: controller.isLoading.value ? null : controller.login,
                      child: controller.isLoading.value
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Entrar'),
                    )),
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Expanded(
                      child: Divider(color: Color(0xFFE5E7EB), thickness: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'ou',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(color: Color(0xFFE5E7EB), thickness: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                OutlinedButton(
                  onPressed: controller.loginWithGoogle,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textDark,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _GoogleLogo(),
                      const SizedBox(width: 12),
                      const Text(
                        'Continuar com Google',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (Platform.isIOS) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: controller.loginWithApple,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.apple, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Continuar com Apple',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Não tem conta? ',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      GestureDetector(
                        onTap: controller.goToRegister,
                        child: const Text(
                          'Cadastre-se grátis',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = w / 2;

    // Red arc (top-right going clockwise from ~315° to ~45°)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -2.35, 1.57, false,
      Paint()
        ..color = const Color(0xFFEA4335)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.22
        ..strokeCap = StrokeCap.butt,
    );
    // Green arc (bottom-right)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -0.78, 1.57, false,
      Paint()
        ..color = const Color(0xFF34A853)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.22
        ..strokeCap = StrokeCap.butt,
    );
    // Yellow arc (bottom-left)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      0.79, 1.2, false,
      Paint()
        ..color = const Color(0xFFFBBC05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.22
        ..strokeCap = StrokeCap.butt,
    );
    // Blue arc (left side)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      1.99, 1.18, false,
      Paint()
        ..color = const Color(0xFF4285F4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.22
        ..strokeCap = StrokeCap.butt,
    );

    // Blue horizontal bar (the middle bar of the G)
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx, cy - h * 0.12, w * 0.5, h * 0.24),
        const Radius.circular(2),
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter oldDelegate) => false;
}
