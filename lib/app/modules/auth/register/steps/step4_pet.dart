import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../theme/app_theme.dart';
import '../register_controller.dart';

class Step4Pet extends GetView<RegisterController> {
  const Step4Pet({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: controller.formStep4Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Text('Seu pet',
                style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 4),
            Text('Pode adicionar mais pets depois',
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 28),

            // Foto do pet
            Center(
              child: GestureDetector(
                onTap: controller.pickPetPhoto,
                child: Obx(() {
                  final photo = controller.petPhotoBase64.value;
                  return Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.1),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 2),
                      image: photo.isEmpty
                          ? null
                          : DecorationImage(
                              image: MemoryImage(
                                  base64Decode(photo.split(',').last)),
                              fit: BoxFit.cover,
                            ),
                    ),
                    child: photo.isEmpty
                        ? const Icon(Icons.camera_alt_outlined,
                            color: AppColors.primary, size: 32)
                        : null,
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: controller.petNameController,
              validator: controller.validatePetName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'Nome do pet'),
            ),
            const SizedBox(height: 18),

            // Espécie
            Text('Espécie',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    )),
            const SizedBox(height: 10),
            Obx(() => Row(
                  children: [
                    _SpeciesChip(
                      label: 'Gato',
                      emoji: '🐱',
                      selected: controller.petSpecies.value == 'cat',
                      onTap: () => controller.selectPetSpecies('cat'),
                    ),
                    const SizedBox(width: 10),
                    _SpeciesChip(
                      label: 'Cão',
                      emoji: '🐶',
                      selected: controller.petSpecies.value == 'dog',
                      onTap: () => controller.selectPetSpecies('dog'),
                    ),
                    const SizedBox(width: 10),
                    _SpeciesChip(
                      label: 'Outro',
                      emoji: '🐾',
                      selected: controller.petSpecies.value == 'other',
                      onTap: () => controller.selectPetSpecies('other'),
                    ),
                  ],
                )),
            const SizedBox(height: 16),

            // Sexo
            const SizedBox(height: 16),
            Text('Sexo',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    )),
            const SizedBox(height: 10),
            Obx(() => Row(
                  children: [
                    _SexChip(
                      label: 'Macho',
                      icon: Icons.male,
                      selected: controller.petSex.value == 'male',
                      onTap: () => controller.selectPetSex('male'),
                    ),
                    const SizedBox(width: 10),
                    _SexChip(
                      label: 'Fêmea',
                      icon: Icons.female,
                      selected: controller.petSex.value == 'female',
                      onTap: () => controller.selectPetSex('female'),
                    ),
                  ],
                )),
            const SizedBox(height: 16),

            TextFormField(
              controller: controller.petBreedController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'Raça'),
            ),
            const SizedBox(height: 14),

            // Idade + Peso
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller.petAgeController,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: 'Idade'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controller.petWeightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    decoration:
                        const InputDecoration(hintText: 'Peso (kg)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Castrado
            Obx(() => GestureDetector(
                  onTap: () =>
                      controller.isCastrated.value = !controller.isCastrated.value,
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: controller.isCastrated.value
                              ? AppColors.primary
                              : Colors.white,
                          border: Border.all(
                            color: controller.isCastrated.value
                                ? AppColors.primary
                                : const Color(0xFFD1D5DB),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: controller.isCastrated.value
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Castrado(a)',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 28),
            Obx(() => ElevatedButton(
                  onPressed: controller.isLoading.value
                      ? null
                      : controller.proceedFromStep4,
                  child: controller.isLoading.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Criar conta'),
                )),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SexChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SexChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: selected ? Colors.white : AppColors.textMedium),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeciesChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _SpeciesChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
