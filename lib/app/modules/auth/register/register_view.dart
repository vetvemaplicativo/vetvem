import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../theme/vv2/vv2_tokens.dart';
import 'register_controller.dart';
import 'steps/register_widgets.dart';
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
          backgroundColor: Vv2Pastel.cream,
          // O conteúdo rola acima do teclado; o campo focado fica visível.
          resizeToAvoidBottomInset: true,
          body: DefaultTextStyle(
            style: Vv2.bodyLarge,
            child: Column(
              children: [
                RegHeader(
                  step: step,
                  total: RegisterController.totalSteps,
                  title: _titles[step],
                  onBack: controller.prevStep,
                ),
                Expanded(
                  // Corpo creme com cantos arredondados sobre o degradê.
                  child: Transform.translate(
                    offset: const Offset(0, -20),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Vv2Pastel.cream,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.06, 0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                                parent: animation, curve: Curves.easeOut)),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(step),
                          child: _stepWidget(step),
                        ),
                      ),
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
      case 1:
        return const Step3Address();
      case 2:
        return const Step4Pet();
      default:
        return const Step2PersonalData();
    }
  }
}
