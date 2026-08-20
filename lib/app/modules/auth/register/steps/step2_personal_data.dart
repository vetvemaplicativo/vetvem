import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/input_formatters.dart';
import '../register_controller.dart';

class Step2PersonalData extends GetView<RegisterController> {
  const Step2PersonalData({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: controller.formStep2Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Text('Seus dados',
                style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 32),

            TextFormField(
              controller: controller.nameController,
              validator: controller.validateName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'Nome completo'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: controller.emailController,
              validator: controller.validateEmail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'E-mail'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: controller.phoneController,
              validator: controller.validatePhone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [PhoneInputFormatter()],
              decoration:
                  const InputDecoration(hintText: 'Celular (WhatsApp)'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: controller.cpfController,
              validator: controller.validateCpf,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [CpfInputFormatter()],
              decoration: const InputDecoration(hintText: 'CPF'),
            ),
            const SizedBox(height: 14),
            Obx(() => TextFormField(
                  controller: controller.passwordController,
                  validator: controller.validatePassword,
                  obscureText: !controller.isPasswordVisible.value,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => controller.proceedFromStep2(),
                  decoration: InputDecoration(
                    hintText: 'Senha',
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
            const SizedBox(height: 28),
            Obx(() => ElevatedButton(
                  onPressed:
                      controller.isLoading.value ? null : controller.proceedFromStep2,
                  child: controller.isLoading.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Próximo'),
                )),
            const SizedBox(height: 16),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Já tem conta? ',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textMedium)),
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: const Text(
                      'Entrar',
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
    );
  }
}
