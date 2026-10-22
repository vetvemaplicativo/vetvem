import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../profile/profile_controller.dart';
import 'home_controller.dart';

/// Guia da primeira consulta: aparece só para quem ainda não fez nenhum pedido.
/// Os passos se marcam sozinhos conforme a pessoa avança. O texto de pagamento
/// e devolução segue os Termos de Uso (seção 3).
class FirstConsultGuide extends StatelessWidget {
  const FirstConsultGuide({super.key});

  @override
  Widget build(BuildContext context) {
    final home = Get.find<HomeController>();
    final profile = Get.find<ProfileController>();
    return Obx(() {
      // Só depois de carregar os pedidos, para não piscar para quem já pediu.
      if (!home.appointmentsLoaded.value || home.hasAnyAppointment.value) {
        return const SizedBox.shrink();
      }
      final hasPet = profile.pets.isNotEmpty;
      final hasAddress = profile.addresses.isNotEmpty;

      final steps = <_Step>[
        _Step('Cadastre seu pet', hasPet, 'pet',
            () => home.changeTab(3), 'Cadastrar meu pet'),
        _Step('Informe seu endereço', hasAddress, 'address',
            () => home.changeTab(3), 'Informar endereço'),
        _Step('Escolha um veterinário', false, 'vet',
            () => home.changeTab(1), 'Escolher veterinário'),
        _Step('Solicite a consulta e pague', false, 'request',
            () => home.changeTab(1), 'Escolher veterinário'),
      ];
      // Próximo passo pendente em destaque (os dois últimos levam à busca)
      final next = steps.firstWhere((s) => !s.done);

      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sua primeira consulta em 4 passos',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark)),
            const SizedBox(height: 4),
            const Text('O veterinário vai até a sua casa.',
                style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
            const SizedBox(height: 14),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      steps[i].done
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: steps[i].done
                          ? const Color(0xFF22C55E)
                          : AppColors.textLight,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('${i + 1}. ${steps[i].label}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: identical(steps[i], next)
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: steps[i].done
                                  ? AppColors.textLight
                                  : AppColors.textDark)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Get.find<AnalyticsService>().logGuideTap(next.key);
                  next.action();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(next.cta),
              ),
            ),
            const SizedBox(height: 6),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: const ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.only(bottom: 8),
                title: Text('Como funciona o pagamento',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
                children: [
                  _Bullet('Você paga ao solicitar a consulta, por Pix ou cartão de crédito. '
                      'O pedido só chega ao veterinário depois que o pagamento é aprovado.'),
                  _Bullet('O veterinário tem até 2 horas para aceitar ou recusar o pedido.'),
                  _Bullet('Se ele recusar ou não responder, o valor é devolvido '
                      'automaticamente. O prazo para aparecer na sua conta ou fatura '
                      'depende do seu banco ou cartão.'),
                  _Bullet('O pagamento só é repassado ao veterinário depois que o '
                      'atendimento é concluído.'),
                  _Bullet('Para cancelar uma consulta já paga, fale com o nosso suporte '
                      'pelo botão "Cancelar" na aba Consultas.'),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _Step {
  final String label;
  final bool done;
  final String key;
  final VoidCallback action;
  final String cta;
  _Step(this.label, this.done, this.key, this.action, this.cta);
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5, right: 8),
            child: Icon(Icons.circle, size: 5, color: AppColors.textMedium),
          ),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12, height: 1.4, color: AppColors.textMedium)),
          ),
        ],
      ),
    );
  }
}
