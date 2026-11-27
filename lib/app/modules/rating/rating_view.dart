import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../theme/vv2/vv2_tokens.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/vv_header.dart';
import 'rating_controller.dart';

class RatingView extends GetView<RatingController> {
  const RatingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() => controller.isSubmitted.value
        ? const _SuccessView()
        : _RatingForm());
  }
}

// ─── Formulário de avaliação ──────────────────────────────────────────────────

class _RatingForm extends GetView<RatingController> {
  final _commentCtrl = TextEditingController();

  static const _labels = {
    1: 'Ruim',
    2: 'Regular',
    3: 'Bom',
    4: 'Muito bom',
    5: 'Excelente!',
  };

  @override
  Widget build(BuildContext context) {
    final sub = [
      if (controller.specialty.isNotEmpty) controller.specialty,
      controller.petName,
    ].join(' · ');
    return Scaffold(
      backgroundColor: Vv2Pastel.cream,
      body: Column(
        children: [
          VvGradientHeader(
            title: 'Avaliar atendimento',
            onBack: () => Get.back(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  Vv2.gutter, 20, Vv2.gutter, Vv2.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(sub,
                      style: Vv2.t(14, 20, 400, color: Vv2.textSecondary)),
                  const SizedBox(height: 12),
                  _Card(
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Vv2.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person,
                              color: Vv2.primary, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(controller.vetName,
                                  style: Vv2.t(16, 22, 700)),
                              if (controller.date.isNotEmpty)
                                Text(controller.date,
                                    style: Vv2.t(13, 18, 400,
                                        color: Vv2.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Como foi o atendimento?',
                            style: Vv2.t(16, 22, 700)),
                        const SizedBox(height: 2),
                        Text(
                          'Sua avaliação ajuda outros tutores a escolherem o profissional ideal.',
                          style:
                              Vv2.t(13, 18, 400, color: Vv2.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Text('Nota', style: Vv2.t(13, 18, 700)),
                        Obx(() => _StarPicker(
                              selected: controller.selectedStars.value,
                              onSelect: controller.selectStars,
                            )),
                        Obx(() {
                          final stars = controller.selectedStars.value;
                          return Text(
                            _labels[stars] ??
                                'Toque nas estrelas para dar a nota',
                            style: Vv2.t(14, 20, 700,
                                color: stars > 0
                                    ? Vv2.primary
                                    : Vv2.textSecondary),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Comentário (opcional)',
                            style: Vv2.t(14, 20, 700)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _commentCtrl,
                          maxLines: 4,
                          maxLength: 300,
                          decoration: InputDecoration(
                            hintText:
                                'Conte como foi a experiência com ${controller.vetName}...',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Obx(() => VvPillButton(
                        label: 'Enviar avaliação',
                        loading: controller.isLoading.value,
                        onTap: controller.isLoading.value
                            ? null
                            : () => controller.submit(_commentCtrl.text),
                      )),
                  const SizedBox(height: 8),
                  VvPillButton(
                    label: 'Avaliar depois',
                    kind: VvPillKind.outlined,
                    onTap: () => Get.back(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Vv2.surface,
          borderRadius: BorderRadius.circular(Vv2.rCard),
          border: Border.all(color: Vv2.pressedSurface),
        ),
        child: child,
      );
}

// ─── Seletor de estrelas ──────────────────────────────────────────────────────

class _StarPicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _StarPicker({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: List.generate(5, (i) {
        final star = i + 1;
        final filled = star <= selected;
        return Semantics(
          button: true,
          selected: filled,
          label: '$star de 5 estrelas',
          excludeSemantics: true,
          child: InkResponse(
            onTap: () => onSelect(star),
            radius: 26,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 44,
                color: filled ? Vv2.brand : Vv2.outline,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Tela de sucesso ──────────────────────────────────────────────────────────

class _SuccessView extends GetView<RatingController> {
  const _SuccessView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Vv2Pastel.cream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      color: Vv2.successBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        color: Vv2.successFg, size: 56),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Obrigado pela\nsua avaliação!',
                  textAlign: TextAlign.center,
                  style: Vv2.t(26, 32, 700),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sua opinião sobre ${controller.vetName} foi registrada e vai ajudar outros tutores a fazerem a melhor escolha.',
                  textAlign: TextAlign.center,
                  style: Vv2.t(14, 22, 400, color: Vv2.textSecondary),
                ),
                const SizedBox(height: 16),
                // Exibe as estrelas que o usuário deu
                Obx(() => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final filled = i < controller.selectedStars.value;
                        return Icon(
                          filled
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: filled ? Vv2.brand : Vv2.outline,
                          size: 32,
                        );
                      }),
                    )),
                const SizedBox(height: 48),
                VvPillButton(
                  label: 'Voltar ao início',
                  onTap: controller.goBack,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
