import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/vv2/vv_icons.dart';
import '../../theme/vv2/vv2_tokens.dart';
import '../../widgets/auth_widgets.dart';
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
            () => home.changeTab(3), 'Informar meu endereço'),
        _Step('Escolha um veterinário', false, 'vet',
            () => home.changeTab(1), 'Escolher veterinário'),
        _Step('Solicite a consulta e pague', false, 'request',
            () => home.changeTab(1), 'Escolher veterinário'),
      ];
      // Próximo passo pendente em destaque (os dois últimos levam à busca)
      final next = steps.firstWhere((s) => !s.done);

      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
        decoration: BoxDecoration(
          color: Vv2.surface,
          borderRadius: BorderRadius.circular(Vv2.rOverlay),
          boxShadow: Vv2.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sua primeira consulta em 4 passos',
                style: Vv2.t(18, 24, 700)),
            const SizedBox(height: 4),
            Text('O veterinário vai até a sua casa.',
                style: Vv2.t(14, 20, 400, color: Vv2.textSecondary)),
            const SizedBox(height: 14),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: steps[i].done
                            ? Vv2.successBg
                            : Vv2.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: steps[i].done
                          ? const VvIcon(VvFn.check,
                              size: 16, color: Vv2.successFg)
                          : Text('${i + 1}', style: Vv2.t(13, 18, 700)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        label: steps[i].done
                            ? '${steps[i].label}, concluído'
                            : steps[i].label,
                        excludeSemantics: true,
                        child: Text(steps[i].label,
                            style: Vv2.t(
                                16,
                                22,
                                identical(steps[i], next) ? 700 : 400)),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            VvPillButton(
              label: next.cta,
              arrow: true,
              onTap: () {
                Get.find<AnalyticsService>().logGuideTap(next.key);
                next.action();
              },
            ),
            const SizedBox(height: 4),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                iconColor: Vv2.primary,
                collapsedIconColor: Vv2.primary,
                title: Text('Como funciona o pagamento',
                    style: Vv2.t(15, 20, 700, color: Vv2.primary)),
                children: const [
                  _Bullet('Você paga ao solicitar a consulta, por Pix ou cartão de crédito. '
                      'O pedido só chega ao veterinário depois que o pagamento é aprovado.'),
                  _Bullet('O veterinário tem até 3 horas para aceitar ou recusar o pedido.'),
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
                style: Vv2.t(14, 20, 400, color: Vv2.textSecondary)),
          ),
        ],
      ),
    );
  }
}
