import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_theme.dart';
import 'service_area_controller.dart';
import 'widgets/service_area_selector.dart';

class ServiceAreaView extends GetView<ServiceAreaController> {
  const ServiceAreaView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Área de atuação')),
      body: Obx(() {
        if (controller.isLoadingExisting.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Onde você atende?',
                style: Get.textTheme.displayMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Tutores só encontram você nos bairros e cidades '
                'que você escolher aqui.',
                style: Get.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              const ServiceAreaSelector(),
              const SizedBox(height: 100),
            ],
          ),
        );
      }),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Obx(() => ElevatedButton(
                onPressed: controller.isSaving.value ? null : controller.save,
                child: controller.isSaving.value
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text('Salvar área de atuação'),
              )),
        ),
      ),
    );
  }
}
