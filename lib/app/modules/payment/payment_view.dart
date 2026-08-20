import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../theme/app_theme.dart';
import '../profile/profile_controller.dart';
import 'payment_controller.dart';

class PaymentView extends GetView<PaymentController> {
  const PaymentView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      switch (controller.status.value) {
        case PaymentStatus.selecting:
          return const _MethodSelectView();
        case PaymentStatus.pixWaiting:
          return const _PixView();
        case PaymentStatus.cardForm:
          return const _CardFormView();
        case PaymentStatus.processing:
          return const _ProcessingView();
        case PaymentStatus.approved:
          return const _ApprovedView();
        case PaymentStatus.rejected:
          return const _RejectedView();
      }
    });
  }
}

// ─── Resumo do agendamento ────────────────────────────────────────────────────

class _AppointmentSummary extends GetView<PaymentController> {
  const _AppointmentSummary();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pets, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.vetName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
                if (controller.serviceName.isNotEmpty)
                  Text(
                    controller.serviceName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                Text(
                  '${controller.petName} · ${controller.appointmentDate} às ${controller.appointmentTime}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMedium),
                ),
              ],
            ),
          ),
          Text(
            'R\$ ${controller.price.toStringAsFixed(2).replaceAll('.', ',')}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Seleção de método ────────────────────────────────────────────────────────

class _MethodSelectView extends GetView<PaymentController> {
  const _MethodSelectView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pagamento'),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AppointmentSummary(),
            const SizedBox(height: 28),

            // ── PIX ──────────────────────────────────────────────────
            const Text('Pix', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.textMedium)),
            const SizedBox(height: 8),
            _MethodCard(
              icon: Icons.pix_outlined,
              title: 'Pagar com Pix',
              subtitle: 'Aprovação imediata',
              badge: 'Recomendado',
              onTap: controller.selectPix,
            ),

            const SizedBox(height: 20),

            // ── Cartão de crédito ────────────────────────────────────
            const Text('Cartão de crédito', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.textMedium)),
            const SizedBox(height: 8),
            _SavedCardsSection(),

            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, color: AppColors.success, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pagamento seguro. Seus dados são criptografados e protegidos.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMedium),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Cartões salvos ───────────────────────────────────────────────────────────

class _SavedCardsSection extends GetView<PaymentController> {
  void _showCvvSheet(BuildContext context, SavedCard card) {
    final cvvCtrl = TextEditingController();
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${card.brand} •••• ${card.lastFour}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                    fontFamily: 'Poppins')),
            const SizedBox(height: 4),
            const Text('Digite o código de segurança para confirmar',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMedium,
                    fontFamily: 'Poppins')),
            const SizedBox(height: 16),
            TextField(
              controller: cvvCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 4,
              obscureText: true,
              style: const TextStyle(fontSize: 20, letterSpacing: 8),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'CVV',
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final cvv = cvvCtrl.text.trim();
                if (cvv.length < 3) return;
                Get.back();
                controller.payWithSavedCard(card, cvv);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Confirmar pagamento',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins')),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = Get.find<ProfileController>();
    return Obx(() {
      final cards = profile.savedCards;
      return Column(
        children: [
          ...cards.map((card) {
            return GestureDetector(
              onTap: () => card.canQuickPay
                  ? _showCvvSheet(context, card)
                  : controller.selectCard(),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
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
                      width: 44,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.credit_card_rounded,
                          color: AppColors.textMedium, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${card.brand} •••• ${card.lastFour}',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark)),
                          Text(
                              card.canQuickPay
                                  ? 'Pague só com o CVV · Validade ${card.expiry}'
                                  : '${card.holderName} · Validade ${card.expiry}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: card.canQuickPay
                                      ? AppColors.success
                                      : AppColors.textMedium)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        size: 14, color: AppColors.textLight),
                  ],
                ),
              ),
            );
          }),


          // Adicionar novo cartão
          GestureDetector(
            onTap: controller.selectCard,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_card_outlined,
                      color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Adicionar novo cartão',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMedium),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}

// ─── Pix ──────────────────────────────────────────────────────────────────────

class _PixView extends GetView<PaymentController> {
  const _PixView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pagar com Pix'),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => controller.status.value = PaymentStatus.selecting,
        ),
      ),
      body: Obx(() {
        if (controller.pixLoading.value) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
                SizedBox(height: 20),
                Text('Gerando PIX...', style: TextStyle(color: AppColors.textMedium)),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const _AppointmentSummary(),
              const SizedBox(height: 28),

              // QR Code real (base64 do Mercado Pago)
              if (controller.pixQrCodeBase64.value.isNotEmpty)
                Container(
                  width: 210,
                  height: 210,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                    boxShadow: [
                      BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Image.memory(
                    base64Decode(controller.pixQrCodeBase64.value),
                    fit: BoxFit.contain,
                  ),
                )
              else
                Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                  ),
                  child: const Icon(Icons.pix, color: AppColors.primary, size: 64),
                ),

              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: AppColors.textMedium),
                  const SizedBox(width: 4),
                  Obx(() => Text(
                    'Expira em ${controller.pixFormattedCountdown}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textMedium),
                  )),
                ],
              ),
              const SizedBox(height: 8),

              // Aguardando confirmação
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.success,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('Aguardando confirmação do pagamento...',
                        style: TextStyle(fontSize: 12, color: AppColors.success)),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Copia e cola
              if (controller.pixCopyPaste.value.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pix copia e cola',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.textDark)),
                      const SizedBox(height: 8),
                      Text(
                        controller.pixCopyPaste.value,
                        style: const TextStyle(fontSize: 11, color: AppColors.textMedium),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: controller.pixCopyPaste.value));
                          Get.snackbar('Copiado!', 'Código PIX copiado',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: AppColors.success,
                              colorText: Colors.white,
                              duration: const Duration(seconds: 2),
                              margin: const EdgeInsets.all(16),
                              borderRadius: 12);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.copy, size: 16, color: AppColors.primary),
                              SizedBox(width: 6),
                              Text('Copiar código PIX',
                                  style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),
              const _PixSteps(),
              const SizedBox(height: 16),
            ],
          ),
        );
      }),
    );
  }
}

class _PixSteps extends StatelessWidget {
  const _PixSteps();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.smartphone, 'Abra o app do seu banco'),
      (Icons.pix_outlined, 'Escolha pagar com Pix'),
      (Icons.qr_code_scanner, 'Escaneie o QR Code ou cole a chave'),
      (Icons.check_circle_outline, 'Confirme o valor e pague'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Como pagar',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 10),
        ...steps.indexed.map(((int, (IconData, String)) e) {
          final (i, (icon, text)) = e;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(icon, size: 16, color: AppColors.textMedium),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 13, color: AppColors.textMedium),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─── Cartão ───────────────────────────────────────────────────────────────────

class _CardFormView extends GetView<PaymentController> {
  const _CardFormView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cartão de crédito'),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => controller.status.value = PaymentStatus.selecting,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _AppointmentSummary(),
              const SizedBox(height: 28),
              // Card visual
              const _CardPreview(),
              const SizedBox(height: 28),
              TextFormField(
                controller: controller.cardNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [_CardNumberFormatter()],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Informe o número do cartão';
                  if (v.replaceAll(RegExp(r'\D'), '').length < 16) return 'Número inválido';
                  return null;
                },
                decoration: const InputDecoration(
                  hintText: '0000 0000 0000 0000',
                  labelText: 'Número do cartão',
                  prefixIcon: Icon(Icons.credit_card_outlined, color: AppColors.textLight),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller.cardHolderController,
                textCapitalization: TextCapitalization.characters,
                validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome' : null,
                decoration: const InputDecoration(
                  hintText: 'NOME COMO NO CARTÃO',
                  labelText: 'Nome do titular',
                  prefixIcon: Icon(Icons.person_outlined, color: AppColors.textLight),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: controller.expiryController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_ExpiryFormatter()],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Validade';
                        if (v.length < 5) return 'MM/AA inválido';
                        return null;
                      },
                      decoration: const InputDecoration(
                        hintText: 'MM/AA',
                        labelText: 'Validade',
                        prefixIcon: Icon(Icons.calendar_today, color: AppColors.textLight, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: controller.cvvController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      onTap: () => controller.isCardFlipped.value = true,
                      onEditingComplete: () => controller.isCardFlipped.value = false,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'CVV';
                        if (v.length < 3) return 'CVV inválido';
                        return null;
                      },
                      decoration: const InputDecoration(
                        hintText: '123',
                        labelText: 'CVV',
                        counterText: '',
                        prefixIcon: Icon(Icons.lock_outline, color: AppColors.textLight, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller.cpfController,
                keyboardType: TextInputType.number,
                inputFormatters: [_CpfFormatter()],
                decoration: const InputDecoration(
                  hintText: '000.000.000-00',
                  labelText: 'CPF do titular',
                  prefixIcon: Icon(Icons.badge_outlined, color: AppColors.textLight, size: 20),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: controller.submitCard,
                child: Text(
                  'Pagar R\$ ${controller.price.toStringAsFixed(2).replaceAll('.', ',')}',
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 13, color: AppColors.textLight),
                    SizedBox(width: 4),
                    Text(
                      'Pagamento seguro com criptografia SSL',
                      style: TextStyle(fontSize: 11, color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardPreview extends StatefulWidget {
  const _CardPreview();

  @override
  State<_CardPreview> createState() => _CardPreviewState();
}

class _CardPreviewState extends State<_CardPreview> {
  late final PaymentController _c;
  late final Worker _flipWorker;

  @override
  void initState() {
    super.initState();
    _c = Get.find<PaymentController>();
    _c.cardNumberController.addListener(_rebuild);
    _c.cardHolderController.addListener(_rebuild);
    _c.expiryController.addListener(_rebuild);
    _flipWorker = ever(_c.isCardFlipped, (_) => _rebuild());
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _c.cardNumberController.removeListener(_rebuild);
    _c.cardHolderController.removeListener(_rebuild);
    _c.expiryController.removeListener(_rebuild);
    _flipWorker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final num = _c.cardNumberController.text;
    final holder = _c.cardHolderController.text;
    final expiry = _c.expiryController.text;
    final flipped = _c.isCardFlipped.value;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'VetVem',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Icon(
                flipped ? Icons.credit_card : Icons.credit_card_outlined,
                color: Colors.white70,
                size: 32,
              ),
            ],
          ),
          const Spacer(),
          Text(
            num.isEmpty ? '•••• •••• •••• ••••' : num.padRight(19, '•'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              letterSpacing: 2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  holder.isEmpty ? 'NOME DO TITULAR' : holder.toUpperCase(),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                expiry.isEmpty ? 'MM/AA' : expiry,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Processando ──────────────────────────────────────────────────────────────

class _ProcessingView extends StatelessWidget {
  const _ProcessingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
            SizedBox(height: 24),
            Text(
              'Processando pagamento...',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Aprovado ─────────────────────────────────────────────────────────────────

class _ApprovedView extends GetView<PaymentController> {
  const _ApprovedView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 64),
              ),
              const SizedBox(height: 24),
              const Text(
                'Pagamento realizado!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Aguardando confirmação do profissional.\nVocê será notificado assim que ele confirmar.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textMedium, height: 1.5),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: Color(0xFFD97706)),
                    SizedBox(width: 6),
                    Text(
                      'O valor fica retido até a confirmação',
                      style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  children: [
                    _InfoRow(icon: Icons.person_outline, label: 'Veterinário', value: controller.vetName),
                    const Divider(height: 20),
                    if (controller.serviceName.isNotEmpty) ...[
                      _InfoRow(icon: Icons.medical_services_outlined, label: 'Serviço', value: controller.serviceName),
                      const Divider(height: 20),
                    ],
                    _InfoRow(icon: Icons.pets, label: 'Pet', value: controller.petName),
                    const Divider(height: 20),
                    _InfoRow(icon: Icons.calendar_today, label: 'Data', value: controller.appointmentDate),
                    const Divider(height: 20),
                    _InfoRow(icon: Icons.access_time, label: 'Horário', value: controller.appointmentTime),
                    const Divider(height: 20),
                    _InfoRow(
                      icon: Icons.attach_money,
                      label: 'Valor pago',
                      value: 'R\$ ${controller.price.toStringAsFixed(2).replaceAll('.', ',')}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: controller.goToConsultas,
                child: const Text('Ver minhas consultas'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: controller.goToHome,
                child: const Text('Ir para início'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Rejeitado ────────────────────────────────────────────────────────────────

class _RejectedView extends GetView<PaymentController> {
  const _RejectedView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cancel_rounded,
                    color: AppColors.error, size: 64),
              ),
              const SizedBox(height: 24),
              const Text(
                'Pagamento recusado',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Seu cartão foi recusado. Verifique os dados ou tente outro método de pagamento.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textMedium, height: 1.5),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: controller.retryCard,
                child: const Text('Tentar novamente'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => controller.status.value = PaymentStatus.selecting,
                child: const Text('Escolher outro método'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 12),
        Text('$label:',
            style: const TextStyle(color: AppColors.textMedium, fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textDark),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.substring(0, digits.length > 16 ? 16 : digits.length);
    final buffer = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(limited[i]);
    }
    final str = buffer.toString();
    return TextEditingValue(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.substring(0, digits.length > 4 ? 4 : digits.length);
    final buffer = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(limited[i]);
    }
    final str = buffer.toString();
    return TextEditingValue(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

class _CpfFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.substring(0, digits.length > 11 ? 11 : digits.length);
    final buffer = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(limited[i]);
    }
    final str = buffer.toString();
    return TextEditingValue(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}
