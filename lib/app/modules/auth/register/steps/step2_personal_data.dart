import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../theme/vv2/vv2_tokens.dart';
import '../../../../utils/input_formatters.dart';
import '../../../../widgets/auth_widgets.dart';
import '../register_controller.dart';
import 'register_widgets.dart';

class Step2PersonalData extends GetView<RegisterController> {
  const Step2PersonalData({super.key});

  @override
  Widget build(BuildContext context) {
    return RegScroll(
      child: Form(
        key: controller.formStep2Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: controller.nameController,
              validator: controller.validateName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              style: Vv2.bodyLarge,
              decoration: regDecoration('Nome completo'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: controller.emailController,
              validator: controller.validateEmail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              style: Vv2.bodyLarge,
              decoration: regDecoration('E-mail'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: controller.phoneController,
              validator: controller.validatePhone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [PhoneInputFormatter()],
              style: Vv2.bodyLarge,
              decoration: regDecoration('Celular (WhatsApp)'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: controller.cpfController,
              validator: controller.validateCpf,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [CpfInputFormatter()],
              style: Vv2.bodyLarge,
              decoration: regDecoration('CPF'),
            ),
            const SizedBox(height: 14),
            Obx(() => TextFormField(
                  controller: controller.passwordController,
                  validator: controller.validatePassword,
                  obscureText: !controller.isPasswordVisible.value,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onFieldSubmitted: (_) => controller.proceedFromStep2(),
                  style: Vv2.bodyLarge,
                  decoration: regDecoration(
                    'Senha',
                    suffix: IconButton(
                      tooltip: controller.isPasswordVisible.value
                          ? 'Ocultar senha'
                          : 'Mostrar senha',
                      icon: Icon(
                        controller.isPasswordVisible.value
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Vv2.onBrand,
                      ),
                      onPressed: controller.togglePasswordVisibility,
                    ),
                  ),
                )),
            const SizedBox(height: 28),
            Obx(() => VvPillButton(
                  label: 'Próximo',
                  loading: controller.isLoading.value,
                  onTap: controller.isLoading.value
                      ? null
                      : controller.proceedFromStep2,
                )),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Get.back(),
                style: TextButton.styleFrom(
                    minimumSize: const Size(48, Vv2.tapMin)),
                child: Text('Já tem conta? Entrar',
                    style: Vv2.t(15, 20, 700, color: Vv2.primary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
