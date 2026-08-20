import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../profile/profile_controller.dart';

class ConsultaDetailView extends StatelessWidget {
  const ConsultaDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final item = Get.arguments as ConsultationHistory;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Material(
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 20),
                      onPressed: () => Get.back(),
                    ),
                    const Expanded(
                      child: Text(
                        'Detalhes da consulta',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline de status
                  _StatusTimeline(status: item.status),
                  const SizedBox(height: 24),

                  // Veterinário
                  _Card(
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_outline,
                              color: AppColors.primary, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.vetName,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark)),
                              Text(item.specialty,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMedium)),
                              if (item.vetPhone != null)
                                Text(item.vetPhone!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Serviço + valor
                  _Card(
                    child: Row(
                      children: [
                        _Icon(Icons.medical_services_outlined, AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Serviço',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMedium)),
                              Text(
                                  item.serviceName.isNotEmpty
                                      ? item.serviceName
                                      : item.specialty,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark)),
                            ],
                          ),
                        ),
                        if (item.value.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Valor',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMedium)),
                              Text('R\$ ${item.value}',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary)),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Pet + data/hora
                  Row(
                    children: [
                      Expanded(
                        child: _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Icon(Icons.pets, const Color(0xFFFF6B2B)),
                              const SizedBox(height: 8),
                              const Text('Pet',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMedium)),
                              Text(
                                  item.petName.isNotEmpty
                                      ? item.petName
                                      : '—',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Icon(Icons.access_time_rounded,
                                  AppColors.primary),
                              const SizedBox(height: 8),
                              const Text('Data e hora',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMedium)),
                              Text(item.date,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark)),
                              if (item.time.isNotEmpty)
                                Text('às ${item.time}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMedium)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Pagamento
                  _PaymentCard(item: item),

                  // Avaliação (se já avaliado)
                  if (item.rating != null) ...[
                    const SizedBox(height: 12),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sua avaliação',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMedium)),
                          const SizedBox(height: 6),
                          Row(
                            children: List.generate(
                              5,
                              (i) => Icon(
                                i < item.rating!
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: i < item.rating!
                                    ? const Color(0xFFFBBC05)
                                    : const Color(0xFFD1D5DB),
                                size: 20,
                              ),
                            ),
                          ),
                          if (item.comment != null) ...[
                            const SizedBox(height: 6),
                            Text(item.comment!,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textDark)),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Botões de ação
          if (item.canRate)
            _BottomAction(
              label: 'Avaliar atendimento',
              icon: Icons.star_outline_rounded,
              color: const Color(0xFFFBBC05),
              onTap: () => Get.toNamed(Routes.rating, arguments: {
                'consultationId': item.id,
                'vetName': item.vetName,
                'petName': item.petName,
                'date': item.date,
                'specialty': item.specialty,
              }),
            ),
          if (item.status == 'pending_confirmation')
            _BottomAction(
              label: 'Aguardando confirmação do profissional...',
              icon: Icons.hourglass_top_rounded,
              color: const Color(0xFFF59E0B),
              onTap: null,
            ),
          if (item.status == 'confirmed' && item.paymentStatus == 'pending_payment')
            _BottomAction(
              label: 'Pagar agora e garantir seu horário',
              icon: Icons.account_balance_wallet_rounded,
              color: AppColors.primary,
              onTap: () => Get.toNamed(Routes.payment, arguments: {
                'appointmentId': item.id,
                'vetId': '',
                'vetName': item.vetName,
                'tutorName': '',
                'petName': item.petName,
                'petSpecies': '',
                'petBreed': '',
                'petSex': '',
                'petAge': '',
                'petCastrated': false,
                'petPhotoBase64': item.petPhotoBase64,
                'serviceName': item.serviceName,
                'date': item.date,
                'time': item.time,
                'price': double.tryParse(item.value.replaceAll(',', '.')) ?? 0.0,
                'address': '',
              }),
            ),
          if (item.status == 'confirmed' && item.paymentStatus != 'pending_payment')
            _BottomAction(
              label: 'Consulta confirmada! Até lá 🐾',
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF22C55E),
              onTap: null,
            ),
          if (item.sentToClient && item.prontuario != null)
            _BottomAction(
              label: 'Ver prontuário',
              icon: Icons.history_edu_rounded,
              color: AppColors.primary,
              onTap: () => Get.toNamed(Routes.prontuario, arguments: {
                'item': item,
              }),
            ),
        ],
      ),
    );
  }

}

// ─── Payment Card ─────────────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  final ConsultationHistory item;
  const _PaymentCard({required this.item});

  void _goToPayment() {
    Get.toNamed(Routes.payment, arguments: {
      'appointmentId': item.id,
      'vetId': '',
      'vetName': item.vetName,
      'tutorName': '',
      'petName': item.petName,
      'petSpecies': '',
      'petBreed': '',
      'petSex': '',
      'petAge': '',
      'petCastrated': false,
      'petPhotoBase64': item.petPhotoBase64,
      'serviceName': item.serviceName,
      'date': item.date,
      'time': item.time,
      'price': double.tryParse(item.value.replaceAll(',', '.')) ?? 0.0,
      'address': '',
    });
  }

  @override
  Widget build(BuildContext context) {
    final needsPayment = item.status == 'confirmed' && item.paymentStatus == 'pending_payment';
    final isPaid = item.paymentStatus == 'approved' || item.paymentStatus == 'paid' || item.status == 'completed';
    final isCancelled = item.status == 'cancelled' || item.status == 'rejected';

    if (needsPayment) {
      // Mostra opções de pagamento
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _Icon(Icons.payment_rounded, AppColors.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pagamento pendente',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark)),
                      Text('Escolha como deseja pagar',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMedium)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Pendente',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _goToPayment,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B894).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF00B894).withValues(alpha: 0.3)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.pix_rounded, color: Color(0xFF00B894), size: 24),
                          SizedBox(height: 4),
                          Text('PIX', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF00B894))),
                          Text('Instantâneo', style: TextStyle(fontSize: 10, color: AppColors.textMedium)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _goToPayment,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.credit_card_rounded, color: AppColors.primary, size: 24),
                          SizedBox(height: 4),
                          Text('Cartão', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          Text('Crédito', style: TextStyle(fontSize: 10, color: AppColors.textMedium)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Estado normal (pago, cancelado, aguardando confirmação)
    final color = isCancelled
        ? AppColors.error
        : isPaid
            ? const Color(0xFF22C55E)
            : const Color(0xFFF59E0B);

    final label = isCancelled ? 'Estornado' : isPaid ? 'Pago ✓' : 'Aguardando';

    final description = isCancelled
        ? 'Estornado ao seu método de pagamento'
        : isPaid
            ? 'Pagamento confirmado — obrigado!'
            : 'Será cobrado após confirmação do profissional';

    final methodIcon = item.paymentMethod == 'pix'
        ? Icons.pix_rounded
        : item.paymentMethod == 'card'
            ? Icons.credit_card_rounded
            : Icons.payment_rounded;

    final methodLabel = item.paymentMethod == 'pix'
        ? 'PIX'
        : item.paymentMethod == 'card'
            ? 'Cartão de crédito'
            : 'Pagamento';

    return _Card(
      child: Row(
        children: [
          _Icon(methodIcon, color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(methodLabel,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
                Text(description,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMedium)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ),
        ],
      ),
    );
  }
}

// ─── Timeline ────────────────────────────────────────────────────────────────

class _StatusTimeline extends StatelessWidget {
  final String status;
  const _StatusTimeline({required this.status});

  static const _steps = [
    ('Agendado', Icons.calendar_today_rounded),
    ('Aguardando', Icons.hourglass_top_rounded),
    ('Confirmado', Icons.check_circle_outline_rounded),
    ('Concluído', Icons.verified_rounded),
  ];

  int get _currentStep {
    switch (status) {
      case 'pending_confirmation':
        return 1;
      case 'confirmed':
        return 2;
      case 'completed':
        return 3;
      default:
        return -1; // cancelled/rejected
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentStep;
    final isCancelled = status == 'cancelled' || status == 'rejected';

    if (isCancelled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cancel_rounded,
                color: AppColors.error, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status == 'rejected'
                        ? 'Consulta recusada pelo profissional'
                        : 'Consulta cancelada',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error),
                  ),
                  const SizedBox(height: 2),
                  const Text('O valor foi estornado ao pagamento original.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMedium)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: List.generate(_steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Linha de conexão
            final stepIndex = i ~/ 2;
            final done = stepIndex < current;
            return Expanded(
              child: Container(
                height: 2,
                color: done
                    ? AppColors.primary
                    : const Color(0xFFE5E7EB),
              ),
            );
          }
          final stepIndex = i ~/ 2;
          final done = stepIndex <= current;
          final active = stepIndex == current;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: done
                      ? AppColors.primary
                      : const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                  border: active
                      ? Border.all(color: AppColors.primary, width: 2)
                      : null,
                ),
                child: Icon(
                  _steps[stepIndex].$2,
                  size: 16,
                  color: done ? Colors.white : const Color(0xFFD1D5DB),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 62,
                child: Text(
                  _steps[stepIndex].$1,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: active || done
                        ? FontWeight.w700
                        : FontWeight.normal,
                    color: done
                        ? AppColors.primary
                        : AppColors.textLight,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }
}

class _Icon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _Icon(this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

class _BottomAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _BottomAction(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
            20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: onTap != null ? color : color.withValues(alpha: 0.08),
          border: Border(top: BorderSide(color: color.withValues(alpha: 0.3))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: onTap != null ? Colors.white : color, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: onTap != null ? Colors.white : color,
                    fontFamily: 'Poppins')),
          ],
        ),
      ),
    );
  }
}
