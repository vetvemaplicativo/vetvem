import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StepIndicator extends StatelessWidget {
  final int totalSteps;
  final int currentStep;

  const StepIndicator({
    super.key,
    required this.totalSteps,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index <= currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          height: 4,
          width: isActive ? 28 : 20,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
