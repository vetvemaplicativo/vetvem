import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../routes/app_routes.dart';
import '../../theme/vv2/vv_icons.dart';
import '../../theme/vv2/vv2_tokens.dart';
import '../../widgets/auth_widgets.dart';
import '../profile/profile_controller.dart';
import 'consulta_status.dart';
import 'paid_extras_card.dart';
import 'proposal_card.dart';
import 'relocation_card.dart';
import 'vet_photo.dart';

class ConsultaDetailView extends StatelessWidget {
  const ConsultaDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final arg = Get.arguments as ConsultationHistory;
    final profile = Get.find<ProfileController>();

    // Tela ao vivo: acompanha o pedido na lista (que o Firestore atualiza), para que
    // os cartões de escolha apareçam/sumam sozinhos quando o servidor muda o estado.
    return Obx(() {
      final item =
          profile.recentConsultations.firstWhereOrNull((c) => c.id == arg.id) ??
          arg;
      return _buildDetail(context, item);
    });
  }

  Widget _buildDetail(BuildContext context, ConsultationHistory item) {
    return Scaffold(
      backgroundColor: Vv2Pastel.cream,
      body: Column(
        children: [
          const _DetailHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                Vv2.gutter,
                20,
                Vv2.gutter,
                20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Escolhas pendentes do tutor: dentro da área rolável (antes ficavam na
                  // barra fixa de baixo e a lista de profissionais/botões ficava cortada).
                  if (item.awaitingProposal) ProposalCard(item: item),
                  if (item.awaitingRelocation)
                    RelocationCard(item: item, onDone: () => Get.back()),
                  // Timeline de status
                  _StatusTimeline(status: item.status, item: item),
                  const SizedBox(height: 24),

                  // Veterinário: foto, nome e CRMV
                  FutureBuilder<VetPublic>(
                    future: vetPublicOf(item.vetId),
                    builder: (_, snap) {
                      final crmv = item.vetCrmv.isNotEmpty
                          ? item.vetCrmv
                          : (snap.data?.crmv ?? '');
                      final showSpecialty =
                          item.specialty.isNotEmpty &&
                          item.specialty != item.serviceName;
                      return _Card(
                        child: Row(
                          children: [
                            VetPhotoAvatar(vetId: item.vetId, size: 56),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.vetName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Vv2.text,
                                    ),
                                  ),
                                  if (crmv.isNotEmpty)
                                    Text(
                                      'CRMV $crmv',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Vv2.textSecondary,
                                      ),
                                    ),
                                  if (showSpecialty)
                                    Text(
                                      item.specialty,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Vv2.textSecondary,
                                      ),
                                    ),
                                  if (item.vetPhone != null)
                                    Text(
                                      item.vetPhone!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Vv2.primary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Serviço + valor
                  _Card(
                    child: Row(
                      children: [
                        _Icon(Icons.medical_services_outlined, Vv2.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Serviço',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Vv2.textSecondary,
                                ),
                              ),
                              Text(
                                item.serviceName.isNotEmpty
                                    ? item.serviceName
                                    : item.specialty,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Vv2.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (item.value.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Valor',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Vv2.textSecondary,
                                ),
                              ),
                              Text(
                                'R\$ ${item.value}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Vv2.primary,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Pet + data/hora (cartões com a mesma altura)
                  _PairRow(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _PetPhoto(base64Photo: item.petPhotoBase64),
                                const SizedBox(height: 8),
                                const Text(
                                  'Pet',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Vv2.textSecondary,
                                  ),
                                ),
                                Text(
                                  item.petName.isNotEmpty ? item.petName : '—',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Vv2.text,
                                  ),
                                ),
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
                                _Icon(Icons.access_time_rounded, Vv2.primary),
                                const SizedBox(height: 8),
                                const Text(
                                  'Data e hora',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Vv2.textSecondary,
                                  ),
                                ),
                                Text(
                                  item.date,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Vv2.text,
                                  ),
                                ),
                                if (item.time.isNotEmpty)
                                  Text(
                                    'às ${item.time}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Vv2.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Pagamento
                  _PaymentCard(item: item),

                  // Adicionais já pagos (só leitura)
                  PaidExtrasCard(appointmentId: item.id),

                  // Avaliação (se já avaliado)
                  if (item.rating != null) ...[
                    const SizedBox(height: 12),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sua avaliação',
                            style: TextStyle(
                              fontSize: 14,
                              color: Vv2.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: List.generate(
                              5,
                              (i) => Icon(
                                i < item.rating!
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: i < item.rating!
                                    ? const Color(0xFFE0A100)
                                    : const Color(0xFFD1D5DB),
                                size: 20,
                              ),
                            ),
                          ),
                          if (item.comment != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              item.comment!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Vv2.text,
                              ),
                            ),
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
              color: const Color(0xFFE0A100),
              onTap: () => Get.toNamed(
                Routes.rating,
                arguments: {
                  'consultationId': item.id,
                  'vetName': item.vetName,
                  'petName': item.petName,
                  'date': item.date,
                  'specialty': item.specialty,
                },
              ),
            ),
          // Pagamento agora acontece já na solicitação — este botão só
          // aparece se o tutor abandonou o pagamento no meio do caminho
          // (ex.: saiu do PIX antes de pagar) e a solicitação ainda não expirou.
          if (item.awaitingPayment)
            _BottomAction(
              label: 'Pagar agora e garantir seu horário',
              icon: Icons.account_balance_wallet_rounded,
              color: Vv2.primary,
              onTap: () => Get.toNamed(
                Routes.payment,
                arguments: {
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
                  'price':
                      double.tryParse(item.value.replaceAll(',', '.')) ?? 0.0,
                  'address': '',
                },
              ),
            ),
          if (item.paymentInReview)
            _BottomAction(
              label: 'Pagamento em análise...',
              icon: Icons.hourglass_top_rounded,
              color: const Color(0xFF6B4E00),
              onTap: null,
            ),
          if (item.instructionsText.isNotEmpty && item.status == 'confirmed')
            InstructionsCard(text: item.instructionsText),
          if (item.status == 'pending_confirmation' &&
              !item.awaitingPayment &&
              !item.paymentInReview &&
              !item.awaitingProposal &&
              !item.awaitingRelocation)
            _BottomAction(
              label: 'Aguardando confirmação do profissional...',
              icon: Icons.hourglass_top_rounded,
              color: const Color(0xFF6B4E00),
              onTap: null,
            ),
          if (item.status == 'confirmed' &&
              item.paymentStatus != 'pending_payment')
            _BottomAction(
              label: 'Consulta confirmada! Até lá 🐾',
              icon: Icons.check_circle_rounded,
              color: Vv2.successFg,
              onTap: null,
            ),
          if (item.sentToClient && item.prontuario != null)
            _BottomAction(
              label: 'Ver prontuário',
              icon: Icons.history_edu_rounded,
              color: Vv2.primary,
              onTap: () =>
                  Get.toNamed(Routes.prontuario, arguments: {'item': item}),
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
    Get.toNamed(
      Routes.payment,
      arguments: {
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final needsPayment = item.awaitingPayment;
    final isPaid =
        item.paymentStatus == 'approved' ||
        item.paymentStatus == 'paid' ||
        item.status == 'completed';
    final isCancelled = item.status == 'cancelled' || item.status == 'rejected';

    if (needsPayment) {
      // Mostra opções de pagamento
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _Icon(Icons.payment_rounded, Vv2.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pagamento pendente',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Vv2.text,
                        ),
                      ),
                      Text(
                        'Escolha como deseja pagar',
                        style: TextStyle(
                          fontSize: 14,
                          color: Vv2.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Vv2.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Pendente',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Vv2.primary,
                    ),
                  ),
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
                        border: Border.all(
                          color: const Color(0xFF00B894).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.pix_rounded,
                            color: Color(0xFF00B894),
                            size: 24,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'PIX',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF00B894),
                            ),
                          ),
                          Text(
                            'Instantâneo',
                            style: TextStyle(
                              fontSize: 14,
                              color: Vv2.textSecondary,
                            ),
                          ),
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
                        color: Vv2.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Vv2.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.credit_card_rounded,
                            color: Vv2.primary,
                            size: 24,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Cartão',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Vv2.primary,
                            ),
                          ),
                          Text(
                            'Crédito',
                            style: TextStyle(
                              fontSize: 14,
                              color: Vv2.textSecondary,
                            ),
                          ),
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
        ? const Color(0xFF8C1D18)
        : isPaid
        ? Vv2.successFg
        : const Color(0xFF6B4E00);

    final label = isCancelled
        ? 'Estornado'
        : isPaid
        ? 'Pago'
        : item.awaitingPayment
        ? 'Pendente'
        : 'Aguardando';

    final description = isCancelled
        ? 'Estornado ao seu método de pagamento'
        : isPaid
        ? 'Pagamento confirmado — obrigado!'
        : item.paymentInReview
        ? 'Pagamento em análise pelo Mercado Pago'
        : item.awaitingPayment
        ? 'Aguardando pagamento: o pedido só vai ao profissional depois de pago'
        : 'Aguardando confirmação do profissional';

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
                Text(
                  methodLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Vv2.text,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Vv2.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Timeline ────────────────────────────────────────────────────────────────

class _StatusTimeline extends StatelessWidget {
  final String status;
  final ConsultationHistory item;
  const _StatusTimeline({required this.status, required this.item});

  static const _steps = ['Agendado', 'Aguardando', 'Confirmado', 'Concluído'];
  static const _red = Color(0xFF8C1D18);

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
          color: const Color(0xFFFBE3E1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cancel_rounded, color: _red, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.cancelledByTutor
                        ? 'Consulta cancelada pelo tutor'
                        : item.tutorTimedOut
                        ? 'Consulta encerrada: o prazo para escolher terminou'
                        : item.vetNoResponse
                        ? 'Consulta sem resposta do profissional'
                        : status == 'rejected'
                        ? 'Consulta recusada pelo profissional'
                        : 'Consulta cancelada',
                    style: Vv2.t(16, 22, 700, color: _red),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'O valor foi estornado ao pagamento original.',
                    style: Vv2.t(14, 20, 400, color: Vv2.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final st = ConsultaStatus.of(item);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Andamento', style: Vv2.t(16, 22, 700)),
              ConsultaStatusPill(st),
            ],
          ),
          const SizedBox(height: 16),
          Semantics(
            label:
                'Etapa ${current + 1} de ${_steps.length}: ${_steps[current.clamp(0, 3)]}',
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _steps.length; i++)
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 3,
                                color: i == 0
                                    ? Colors.transparent
                                    : i <= current
                                    ? Vv2.primary
                                    : Vv2.divider,
                              ),
                            ),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: i <= current ? Vv2.primary : Vv2.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: i <= current
                                      ? Vv2.primary
                                      : Vv2.divider,
                                  width: 2,
                                ),
                              ),
                              child: i <= current
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: Vv2.onPrimary,
                                    )
                                  : null,
                            ),
                            Expanded(
                              child: Container(
                                height: 3,
                                color: i == _steps.length - 1
                                    ? Colors.transparent
                                    : i < current
                                    ? Vv2.primary
                                    : Vv2.divider,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _steps[i],
                            maxLines: 1,
                            softWrap: false,
                            textAlign: TextAlign.center,
                            style: Vv2.t(
                              12,
                              16,
                              i == current ? 700 : 500,
                              color: i <= current
                                  ? Vv2.text
                                  : Vv2.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _DetailHeader extends StatelessWidget {
  const _DetailHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: Vv2.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Vv2.gutter, 8, Vv2.gutter, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                label: 'Voltar',
                excludeSemantics: true,
                child: Material(
                  color: Vv2.surface.withValues(alpha: 0.85),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Get.back(),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: VvIcon(VvFn.back, size: 22, color: Vv2.onBrand),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                header: true,
                child: Text('Detalhes da consulta', style: Vv2.t(28, 34, 700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dois cartões lado a lado; empilha com texto grande.
class _PairRow extends StatelessWidget {
  final Row child;
  const _PairRow({required this.child});

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    if (scale > 1.25 || MediaQuery.sizeOf(context).width < 340) {
      final kids = child.children
          .whereType<Expanded>()
          .map((e) => e.child)
          .toList();
      return Column(
        children: [
          for (var i = 0; i < kids.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            kids[i],
          ],
        ],
      );
    }
    return IntrinsicHeight(child: child);
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Vv2.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1E0D6)),
      ),
      child: child,
    );
  }
}

/// Foto do pet no cartão do detalhe (ícone de patinha se não houver foto).
class _PetPhoto extends StatelessWidget {
  final String base64Photo;
  const _PetPhoto({required this.base64Photo});

  @override
  Widget build(BuildContext context) {
    if (base64Photo.isNotEmpty) {
      try {
        final bytes = base64Decode(base64Photo.split(',').last);
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: MemoryImage(bytes),
              fit: BoxFit.cover,
            ),
          ),
        );
      } catch (_) {}
    }
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: Vv2.pressedSurface,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: VvIcon(
          VvFn.petFallback,
          size: 24,
          color: Vv2.onPrimaryContainer,
        ),
      ),
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color == Vv2.primary
            ? Vv2.pressedSurface
            : color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color == Vv2.primary ? Vv2.onPrimaryContainer : color,
        size: 22,
      ),
    );
  }
}

/// Ação fixa embaixo. Com toque: botão em pílula; sem toque: aviso em texto.
class _BottomAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _BottomAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    if (onTap != null) {
      return Container(
        color: Vv2Pastel.cream,
        padding: EdgeInsets.fromLTRB(Vv2.gutter, 10, Vv2.gutter, 12 + bottom),
        child: VvPillButton(label: label, onTap: onTap),
      );
    }
    final green = color == Vv2.successFg;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(Vv2.gutter, 14, Vv2.gutter, 14 + bottom),
      decoration: BoxDecoration(
        color: green ? Vv2.successBg : const Color(0xFFFFF1C7),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Vv2.t(15, 20, 700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
