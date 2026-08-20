import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/step_indicator.dart';
import 'register_controller.dart';
import 'steps/step2_personal_data.dart';
import 'steps/step3_address.dart';
import 'steps/step4_pet.dart';

class RegisterView extends GetView<RegisterController> {
  const RegisterView({super.key});

  static const _titles = [
    'Seus dados',
    'Seu endereço',
    'Seu pet',
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final step = controller.currentStep.value;
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) controller.prevStep();
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  size: 20, color: AppColors.textDark),
              onPressed: controller.prevStep,
            ),
            title: Text(
              _titles[step],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Step indicator
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: StepIndicator(
                    totalSteps: RegisterController.totalSteps,
                    currentStep: step,
                  ),
                ),

                // Content — animated transition between steps
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      final offset = Tween<Offset>(
                        begin: const Offset(0.08, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                          parent: animation, curve: Curves.easeOut));
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                            position: offset, child: child),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(step),
                      child: _stepWidget(step),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _stepWidget(int step) {
    switch (step) {
      case 0:
        return const Step2PersonalData();
      case 1:
        return const Step3Address();
      case 2:
        return const Step4Pet();
      default:
        return const Step2PersonalData();
    }
  }
}
