import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header laranja
          Material(
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Get.back(),
                    ),
                    const Expanded(
                      child: Text(
                        'Avaliar consulta',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Card do profissional
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.cardShadow,
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person,
                              color: AppColors.primary, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                controller.vetName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Text(
                                controller.specialty,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMedium),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${controller.petName} · ${controller.date}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textLight),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Pergunta
                  const Text(
                    'Como foi o atendimento?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sua avaliação ajuda outros tutores a\nescolherem o profissional ideal.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMedium,
                        height: 1.5),
                  ),

                  const SizedBox(height: 28),

                  // Estrelas
                  Obx(() => _StarPicker(
                        selected: controller.selectedStars.value,
                        onSelect: controller.selectStars,
                      )),

                  const SizedBox(height: 8),

                  // Label da nota
                  Obx(() {
                    const labels = {
                      1: 'Ruim',
                      2: 'Regular',
                      3: 'Bom',
                      4: 'Muito bom',
                      5: 'Excelente!',
                    };
                    final stars = controller.selectedStars.value;
                    return AnimatedOpacity(
                      opacity: stars > 0 ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        labels[stars] ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 28),

                  // Comentário
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Comentário (opcional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentCtrl,
                    maxLines: 4,
                    maxLength: 300,
                    decoration: InputDecoration(
                      hintText:
                          'Conte como foi a experiência com ${controller.vetName}...',
                      hintStyle:
                          const TextStyle(color: AppColors.textLight, fontSize: 13),
                      counterStyle:
                          const TextStyle(color: AppColors.textLight, fontSize: 11),
                    ),
                  ),

                  const SizedBox(height: 32),

                  Obx(() => ElevatedButton(
                    onPressed: controller.isLoading.value
                        ? null
                        : () => controller.submit(_commentCtrl.text),
                    child: controller.isLoading.value
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : const Text('Enviar avaliação'),
                  )),

                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text(
                      'Avaliar depois',
                      style: TextStyle(color: AppColors.textMedium),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Seletor de estrelas ──────────────────────────────────────────────────────

class _StarPicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _StarPicker({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final star = i + 1;
        final filled = star <= selected;
        return GestureDetector(
          onTap: () => onSelect(star),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 44,
              color: filled ? const Color(0xFFFBBC05) : const Color(0xFFD1D5DB),
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícone animado
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 56),
              ),
              const SizedBox(height: 28),
              const Text(
                'Obrigado pela\nsua avaliação!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                  fontFamily: 'Poppins',
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sua opinião sobre ${controller.vetName} foi registrada e vai ajudar outros tutores a fazerem a melhor escolha.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textMedium,
                  height: 1.6,
                ),
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
                        color: filled
                            ? const Color(0xFFFBBC05)
                            : const Color(0xFFD1D5DB),
                        size: 32,
                      );
                    }),
                  )),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: controller.goBack,
                child: const Text('Voltar ao início'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
