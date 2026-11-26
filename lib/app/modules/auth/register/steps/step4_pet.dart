import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../theme/vv2/vv_icons.dart';
import '../../../../theme/vv2/vv2_tokens.dart';
import '../../../../widgets/auth_widgets.dart';
import '../register_controller.dart';
import 'register_widgets.dart';

class Step4Pet extends GetView<RegisterController> {
  const Step4Pet({super.key});

  @override
  Widget build(BuildContext context) {
    return RegScroll(
      child: Form(
        key: controller.formStep4Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            regSubtitle('Pode adicionar mais pets depois'),

            // Foto do pet: mostra a imagem escolhida quando houver.
            Obx(() {
              final photo = controller.petPhotoBase64.value;
              return Semantics(
                button: true,
                label: photo.isEmpty ? 'Adicionar foto do pet' : 'Trocar foto do pet',
                excludeSemantics: true,
                child: Material(
                  color: Vv2.pressedSurface,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: controller.pickPetPhoto,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Vv2.surface,
                            shape: BoxShape.circle,
                            image: photo.isEmpty
                                ? null
                                : DecorationImage(
                                    image: MemoryImage(
                                        base64Decode(photo.split(',').last)),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          child: photo.isEmpty
                              ? const Center(
                                  child: VvIcon(VvFn.petFallback,
                                      size: 26, color: Vv2.onBrand))
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                              photo.isEmpty
                                  ? 'Adicionar foto do pet'
                                  : 'Trocar foto do pet',
                              style: Vv2.t(16, 22, 700,
                                  color: Vv2.onPrimaryContainer)),
                        ),
                      ]),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 14),

            TextFormField(
              controller: controller.petNameController,
              validator: controller.validatePetName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              style: Vv2.bodyLarge,
              decoration: regDecoration('Nome do pet'),
            ),
            const SizedBox(height: 16),

            regSectionLabel('Espécie'),
            Obx(() => RegChoiceRow(children: [
                  for (final (key, label) in const [
                    ('cat', 'Gato'),
                    ('dog', 'Cão'),
                    ('other', 'Outro'),
                  ])
                    RegChoice(
                      label: label,
                      selected: controller.petSpecies.value == key,
                      leading: VvIcon.species(key, label,
                          size: 22, color: Vv2.onBrand),
                      onTap: () => controller.selectPetSpecies(key),
                    ),
                ])),
            const SizedBox(height: 16),

            regSectionLabel('Sexo'),
            Obx(() => RegChoiceRow(children: [
                  RegChoice(
                    label: 'Macho',
                    selected: controller.petSex.value == 'male',
                    onTap: () => controller.selectPetSex('male'),
                  ),
                  RegChoice(
                    label: 'Fêmea',
                    selected: controller.petSex.value == 'female',
                    onTap: () => controller.selectPetSex('female'),
                  ),
                ])),
            const SizedBox(height: 16),

            TextFormField(
              controller: controller.petBreedController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              style: Vv2.bodyLarge,
              decoration: regDecoration('Raça'),
            ),
            const SizedBox(height: 14),
            RegPair(
              flexA: 1,
              a: TextFormField(
                controller: controller.petAgeController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                style: Vv2.bodyLarge,
                decoration: regDecoration('Idade'),
              ),
              b: TextFormField(
                controller: controller.petWeightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                style: Vv2.bodyLarge,
                decoration: regDecoration('Peso (kg)'),
              ),
            ),
            const SizedBox(height: 8),

            // Castrado(a): linha inteira tocável (alvo de 48).
            Obx(() {
              final on = controller.isCastrated.value;
              return Semantics(
                checked: on,
                label: 'Castrado(a)',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Vv2.rControl),
                  onTap: () => controller.isCastrated.value = !on,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: Vv2.tapMin),
                    child: Row(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: on ? const Color(0xFF6B3A20) : Vv2.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFF6B3A20), width: 1.5),
                        ),
                        child: on
                            ? const Icon(Icons.check,
                                size: 18, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text('Castrado(a)', style: Vv2.t(16, 22, 600)),
                    ]),
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
            Obx(() => VvPillButton(
                  label: 'Criar conta',
                  loading: controller.isLoading.value,
                  onTap: controller.isLoading.value
                      ? null
                      : controller.proceedFromStep4,
                )),
          ],
        ),
      ),
    );
  }
}
