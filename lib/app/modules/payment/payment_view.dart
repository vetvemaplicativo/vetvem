import '../../utils/cpf.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../theme/vv2/vv2_tokens.dart';
import '../../widgets/auth_widgets.dart';
import '../auth/register/steps/register_widgets.dart';
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

// ─── Base visual ──────────────────────────────────────────────────────────────

const _kBorder = Color(0xFFF1E0D6);
const _kRedBg = Color(0xFFFBE3E1);
const _kRedFg = Color(0xFF8C1D18);
const _kAmberBg = Color(0xFFFFF1C7);
const _kAmberFg = Color(0xFF6B4E00);

/// Cabeçalho em gradiente com botão de voltar circular (padrão do Agendamento).
class _PayHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const _PayHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: Vv2.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Vv2.gutter, 12, Vv2.gutter, 40),
          child: Row(
            children: [
              Material(
                color: Vv2.surface,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Voltar',
                  onPressed: onBack,
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 20, color: Vv2.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: Vv2.t(26, 32, 700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tela padrão do pagamento: cabeçalho + conteúdo que sobe sobre o gradiente.
class _PayScaffold extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final Widget child;
  /// true: o voltar do sistema volta para a escolha do método (Pix/cartão).
  final bool interceptBack;
  const _PayScaffold(
      {required this.title, required this.onBack, required this.child, this.interceptBack = true});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !interceptBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack();
      },
      child: Scaffold(
        backgroundColor: Vv2Pastel.cream,
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PayHeader(title: title, onBack: onBack),
              Transform.translate(
                offset: const Offset(0, -24),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(Vv2.gutter, 0, Vv2.gutter,
                      8 + MediaQuery.paddingOf(context).bottom),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color border;
  final EdgeInsets padding;
  const _Box(
      {required this.child,
      this.color = Vv2.surface,
      this.border = _kBorder,
      this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: child,
      );
}

/// Wrap que ocupa a largura toda (valor à direita; quebra para baixo a 130%).
class _SpreadWrap extends StatelessWidget {
  final List<Widget> children;
  final WrapCrossAlignment crossAxisAlignment;
  final double spacing, runSpacing;
  const _SpreadWrap(
      {required this.children,
      WrapAlignment alignment = WrapAlignment.spaceBetween,
      this.crossAxisAlignment = WrapCrossAlignment.start,
      this.spacing = 0,
      this.runSpacing = 0});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: crossAxisAlignment,
          spacing: spacing,
          runSpacing: runSpacing,
          children: children,
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Semantics(
            header: true, child: Text(text, style: Vv2.t(18, 24, 700))),
      );
}

// ─── Resumo do agendamento ────────────────────────────────────────────────────

class _AppointmentSummary extends GetView<PaymentController> {
  const _AppointmentSummary();

  @override
  Widget build(BuildContext context) {
    final quando = controller.appointmentTime.isNotEmpty
        ? '${controller.appointmentDate} · ${controller.appointmentTime}'
        : controller.appointmentDate;
    final linha2 = [
      if (controller.serviceName.isNotEmpty) controller.serviceName,
      if (controller.petName.isNotEmpty) controller.petName,
    ].join(' · ');
    return _Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumo do agendamento', style: Vv2.t(18, 24, 700)),
          const SizedBox(height: 8),
          Text(controller.vetName, style: Vv2.t(16, 22, 700)),
          if (linha2.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(linha2, style: Vv2.t(15, 20, 400, color: Vv2.textSecondary)),
          ],
          const SizedBox(height: 4),
          _SpreadWrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(quando, style: Vv2.t(15, 20, 400, color: Vv2.textSecondary)),
              Text(_brl(controller.price),
                  style: Vv2.t(20, 26, 700, color: Vv2.onPrimaryContainer)),
            ],
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
    return _PayScaffold(
      title: 'Pagamento',
      onBack: Get.back,
      interceptBack: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AppointmentSummary(),
          const _SectionTitle('Pix'),
          _MethodCard(
            title: 'Pagar com Pix',
            subtitle: 'Aprovação imediata',
            badge: 'Recomendado',
            onTap: controller.selectPix,
          ),
          const _SectionTitle('Cartão de crédito'),
          _SavedCardsSection(),
          const SizedBox(height: 20),
          _Box(
            color: Vv2.successBg,
            border: Vv2.successBg,
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 22, color: Vv2.successFg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pagamento seguro. Seus dados são criptografados e protegidos.',
                    style: Vv2.t(15, 22, 500, color: Vv2.successFg),
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

// ─── Cartões salvos ───────────────────────────────────────────────────────────

class _SavedCardsSection extends GetView<PaymentController> {
  void _showCvvSheet(BuildContext context, SavedCard card) {
    final cvvCtrl = TextEditingController();
    final erro = RxnString();
    controller.loadInstallments(paymentMethodId: card.paymentMethodId);
    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        decoration: const BoxDecoration(
          color: Vv2.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(Vv2.gutter, 12, Vv2.gutter,
              24 + MediaQuery.of(context).viewInsets.bottom +
                  MediaQuery.paddingOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Vv2.divider, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              Semantics(
                header: true,
                child: Text('${card.brand} •••• ${card.lastFour}',
                    style: Vv2.t(22, 28, 700)),
              ),
              const SizedBox(height: 4),
              Text('Digite o código de segurança para confirmar',
                  style: Vv2.t(15, 22, 400, color: Vv2.textSecondary)),
              const SizedBox(height: 16),
              Obx(() => TextField(
                    controller: cvvCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 4,
                    obscureText: true,
                    style: Vv2.t(18, 24, 600),
                    decoration: regDecoration('CVV', hint: '123', errorText: erro.value)
                        .copyWith(counterText: ''),
                  )),
              const SizedBox(height: 16),
              const _InstallmentPicker(),
              const _TotalLine(),
              const SizedBox(height: 16),
              Obx(() => VvPillButton(
                    label: _payLabel(controller),
                    onTap: () {
                      final cvv = cvvCtrl.text.trim();
                      if (cvv.length < 3) {
                        erro.value = 'CVV inválido';
                        return;
                      }
                      Get.back();
                      controller.payWithSavedCard(card, cvv);
                    },
                  )),
            ],
          ),
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
      return Container(
        decoration: BoxDecoration(
          color: Vv2.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final card in cards) ...[
                InkWell(
                  onTap: () => card.canQuickPay
                      ? _showCvvSheet(context, card)
                      : controller.selectCard(),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 64),
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${card.brand} •••• ${card.lastFour}',
                                  style: Vv2.t(18, 24, 700)),
                              const SizedBox(height: 2),
                              Text(
                                  card.canQuickPay
                                      ? 'Pague só com o CVV · Validade ${card.expiry}'
                                      : '${card.holderName} · Validade ${card.expiry}',
                                  style: Vv2.t(14, 20, 400, color: Vv2.textSecondary)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            size: 26, color: Vv2.textSecondary),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16, color: Vv2.divider),
              ],
              InkWell(
                onTap: controller.selectCard,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  alignment: Alignment.centerLeft,
                  child: Text('+ Adicionar novo cartão',
                      style: Vv2.t(16, 22, 700, color: Vv2.onPrimaryContainer)),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _MethodCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _MethodCard({
    required this.title,
    required this.subtitle,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle${badge != null ? '. $badge' : ''}',
      excludeSemantics: true,
      child: Material(
        color: Vv2.successBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFCFE3CF)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                      color: Vv2.surface, shape: BoxShape.circle),
                  child: const Icon(Icons.pix_rounded, size: 26, color: Vv2.successFg),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(title, style: Vv2.t(18, 24, 700)),
                          if (badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD5E8D4),
                                borderRadius: BorderRadius.circular(Vv2.rPill),
                              ),
                              child: Text(badge!,
                                  style: Vv2.t(13, 18, 700, color: Vv2.successFg)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: Vv2.t(15, 20, 400, color: Vv2.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 26, color: Vv2.successFg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Pix ──────────────────────────────────────────────────────────────────────

class _PixView extends GetView<PaymentController> {
  const _PixView();

  void _copy() {
    Clipboard.setData(ClipboardData(text: controller.pixCopyPaste.value));
    Get.snackbar('Copiado!', 'Código PIX copiado',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Vv2.successFg,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
        borderRadius: 16);
  }

  @override
  Widget build(BuildContext context) {
    return _PayScaffold(
      title: 'Pagar com Pix',
      onBack: () => controller.status.value = PaymentStatus.selecting,
      child: Obx(() {
        if (controller.pixLoading.value) {
          return _Box(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
            child: Column(
              children: [
                const CircularProgressIndicator(color: Vv2.primary, strokeWidth: 3),
                const SizedBox(height: 20),
                Text('Gerando PIX...',
                    style: Vv2.t(16, 22, 500, color: Vv2.textSecondary)),
              ],
            ),
          );
        }
        final qr = controller.pixQrCodeBase64.value;
        final code = controller.pixCopyPaste.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Box(
              child: _SpreadWrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Valor a pagar',
                          style: Vv2.t(15, 20, 500, color: Vv2.textSecondary)),
                      Text(_brl(controller.price), style: Vv2.t(26, 32, 700)),
                    ],
                  ),
                  Obx(() => Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _kAmberBg,
                          borderRadius: BorderRadius.circular(Vv2.rPill),
                        ),
                        child: Text('Expira em ${controller.pixFormattedCountdown}',
                            style: Vv2.t(14, 20, 700, color: _kAmberFg)),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Box(
              child: Column(
                children: [
                  Text('QR Code Pix', style: Vv2.t(18, 24, 700)),
                  const SizedBox(height: 14),
                  Container(
                    width: 220,
                    height: 220,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE8D5CA)),
                    ),
                    child: qr.isNotEmpty
                        ? Semantics(
                            label: 'QR Code do Pix',
                            image: true,
                            child: Image.memory(base64Decode(qr), fit: BoxFit.contain),
                          )
                        : const Icon(Icons.pix_rounded, color: Vv2.primary, size: 64),
                  ),
                  if (code.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Pix copia e cola', style: Vv2.t(16, 22, 700)),
                    const SizedBox(height: 6),
                    Text(code,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Vv2.t(13, 18, 400, color: Vv2.textSecondary)),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Vv2.successFg),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text('Aguardando confirmação do pagamento…',
                            style: Vv2.t(14, 20, 500, color: Vv2.textSecondary)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (code.isNotEmpty) ...[
              const SizedBox(height: 20),
              VvPillButton(label: 'Copiar código PIX', onTap: _copy),
            ],
            const SizedBox(height: 24),
            const _PixSteps(),
          ],
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
      'Abra o app do seu banco',
      'Escolha pagar com Pix',
      'Escaneie o QR Code ou cole o código',
      'Confirme o valor e pague',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text('Como pagar', style: Vv2.t(18, 24, 700))),
        const SizedBox(height: 10),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: Vv2.pressedSurface, shape: BoxShape.circle),
                  child: Text('${i + 1}',
                      style: Vv2.t(14, 18, 700, color: Vv2.onPrimaryContainer)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(steps[i],
                        style: Vv2.t(15, 22, 400, color: Vv2.textSecondary)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Cartão ───────────────────────────────────────────────────────────────────

class _CardFormView extends GetView<PaymentController> {
  const _CardFormView();

  @override
  Widget build(BuildContext context) {
    final expiry = TextFormField(
      controller: controller.expiryController,
      keyboardType: TextInputType.number,
      inputFormatters: [_ExpiryFormatter()],
      validator: (v) {
        if (v == null || v.isEmpty) return 'Validade';
        if (v.length < 5) return 'MM/AA inválido';
        return null;
      },
      style: Vv2.t(17, 24, 500),
      decoration: regDecoration('Validade', hint: 'MM/AA'),
    );
    final cvv = TextFormField(
      controller: controller.cvvController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      obscureText: true,
      maxLength: 4,
      onTap: () => controller.isCardFlipped.value = true,
      onEditingComplete: () => controller.isCardFlipped.value = false,
      validator: (v) {
        if (v == null || v.isEmpty) return 'CVV';
        if (v.length < 3) return 'CVV inválido';
        return null;
      },
      style: Vv2.t(17, 24, 500),
      decoration: regDecoration('CVV', hint: '123').copyWith(counterText: ''),
    );
    final big = MediaQuery.textScalerOf(context).scale(10) > 12.5;
    return _PayScaffold(
      title: 'Cartão de crédito',
      onBack: () => controller.status.value = PaymentStatus.selecting,
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CardPreview(),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller.cardNumberController,
              keyboardType: TextInputType.number,
              inputFormatters: [_CardNumberFormatter()],
              validator: (v) {
                if (v == null || v.isEmpty) return 'Informe o número do cartão';
                if (v.replaceAll(RegExp(r'\D'), '').length < 16) return 'Número inválido';
                return null;
              },
              style: Vv2.t(17, 24, 500),
              decoration: regDecoration('Número do cartão', hint: '0000 0000 0000 0000'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller.cardHolderController,
              textCapitalization: TextCapitalization.characters,
              validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome' : null,
              style: Vv2.t(17, 24, 500),
              decoration: regDecoration('Nome do titular', hint: 'NOME COMO NO CARTÃO'),
            ),
            const SizedBox(height: 12),
            if (big) ...[
              expiry,
              const SizedBox(height: 12),
              cvv,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: expiry),
                  const SizedBox(width: 12),
                  Expanded(child: cvv),
                ],
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller.cpfController,
              keyboardType: TextInputType.number,
              inputFormatters: [_CpfFormatter()],
              // CPF continua opcional; se preenchido, precisa ser válido (evita recusa por dado errado).
              validator: (v) =>
                  (v == null || v.trim().isEmpty || isValidCpf(v)) ? null : 'CPF inválido',
              style: Vv2.t(17, 24, 500),
              decoration: regDecoration('CPF do titular', hint: '000.000.000-00'),
            ),
            const SizedBox(height: 12),
            const _InstallmentPicker(),
            const _TotalLine(),
            const SizedBox(height: 20),
            Obx(() => VvPillButton(
                  label: _payLabel(controller),
                  onTap: controller.submitCard,
                )),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 16, color: Vv2.textSecondary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text('Pagamento seguro com criptografia SSL',
                      style: Vv2.t(13, 18, 400, color: Vv2.textSecondary)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Total efetivo (com juros do parcelamento, quando houver).
class _TotalLine extends GetView<PaymentController> {
  const _TotalLine();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final o = controller.chosenInstallment;
      final total = o?.total ?? controller.price;
      return _Box(
        child: _SpreadWrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Text('Total', style: Vv2.t(18, 24, 700)),
            Text(_brl(total), style: Vv2.t(20, 26, 700, color: Vv2.onPrimaryContainer)),
          ],
        ),
      );
    });
  }
}

String _payLabel(PaymentController c) {
  final o = c.chosenInstallment;
  return o == null || o.count == 1
      ? 'Pagar ${_brl(o?.total ?? c.price)}'
      : 'Pagar ${o.count}x de ${_brl(o.each)}';
}

class _CardPreview extends StatefulWidget {
  const _CardPreview();

  @override
  State<_CardPreview> createState() => _CardPreviewState();
}

class _CardPreviewState extends State<_CardPreview> {
  late final PaymentController _c;

  @override
  void initState() {
    super.initState();
    _c = Get.find<PaymentController>();
    _c.cardNumberController.addListener(_rebuild);
    _c.cardHolderController.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _c.cardNumberController.removeListener(_rebuild);
    _c.cardHolderController.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final digits = _c.cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    final last = digits.length >= 4 ? digits.substring(digits.length - 4) : '••••';
    final holder = _c.cardHolderController.text;
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Vv2.pressedSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1D3C2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cartão de crédito', style: Vv2.t(18, 24, 700)),
            const SizedBox(height: 14),
            Text('••••  ••••  ••••  $last',
                style: Vv2.t(20, 26, 600).copyWith(letterSpacing: 1)),
            const SizedBox(height: 10),
            Text(holder.isEmpty ? 'NOME DO TITULAR' : holder.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Vv2.t(13, 18, 600, color: Vv2.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ─── Processando ──────────────────────────────────────────────────────────────

class _ProcessingView extends StatelessWidget {
  const _ProcessingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Vv2Pastel.cream,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(
                      color: Vv2.pressedSurface, shape: BoxShape.circle),
                  child: const CircularProgressIndicator(
                      color: Vv2.onPrimaryContainer, strokeWidth: 3.5),
                ),
                const SizedBox(height: 24),
                Semantics(
                  liveRegion: true,
                  child: Text('Processando pagamento…',
                      textAlign: TextAlign.center, style: Vv2.t(24, 30, 700)),
                ),
              ],
            ),
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
    final valor = 'R\$ ${controller.price.toStringAsFixed(2).replaceAll('.', ',')}';
    final quando = controller.appointmentTime.isNotEmpty
        ? '${controller.appointmentDate} às ${controller.appointmentTime}'
        : controller.appointmentDate;
    return Scaffold(
      backgroundColor: Vv2Pastel.cream,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: const BoxDecoration(gradient: Vv2.headerGradient),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Vv2.gutter, 28, Vv2.gutter, 28),
                  child: Column(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(
                            color: Vv2.pressedSurface, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded,
                            size: 48, color: Vv2.onPrimaryContainer),
                      ),
                      const SizedBox(height: 18),
                      Semantics(
                        header: true,
                        child: Text('Agendamento enviado!',
                            textAlign: TextAlign.center, style: Vv2.t(28, 34, 700)),
                      ),
                      const SizedBox(height: 6),
                      Text('Pagamento aprovado. Seu pedido foi enviado ao profissional.',
                          textAlign: TextAlign.center,
                          style: Vv2.t(16, 22, 500, color: Vv2.onBrand)),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(Vv2.gutter, 20, Vv2.gutter,
                  24 + MediaQuery.paddingOf(context).bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WhiteCard(
                    child: Column(
                      children: const [
                        _StepRow(done: true, title: 'Pedido enviado',
                            text: 'O profissional recebeu a solicitação'),
                        SizedBox(height: 14),
                        _StepRow(done: false, title: 'Aguardando confirmação',
                            text: 'O profissional irá aceitar ou recusar'),
                        SizedBox(height: 14),
                        _StepRow(done: false, title: 'Você será notificado',
                            text: 'Receberá um aviso quando ele confirmar'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1C7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'O valor fica retido até a confirmação. Se o profissional não puder atender, ele é devolvido automaticamente.',
                      style: Vv2.t(15, 22, 600, color: const Color(0xFF6B4E00)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _WhiteCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SumLine('Profissional', controller.vetName),
                        if (controller.serviceName.isNotEmpty)
                          _SumLine('Serviço', controller.serviceName),
                        _SumLine('Pet', controller.petName),
                        _SumLine('Data', quando),
                        _SumLine('Valor pago', valor, last: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  VvPillButton(label: 'Ir para início', onTap: controller.goToHome),
                  const SizedBox(height: 12),
                  VvPillButton(
                    label: 'Ver minhas consultas',
                    kind: VvPillKind.outlined,
                    onTap: controller.goToConsultas,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  final Widget child;
  const _WhiteCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Vv2.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1E0D6)),
        ),
        child: child,
      );
}

class _StepRow extends StatelessWidget {
  final bool done;
  final String title, text;
  const _StepRow({required this.done, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: done ? Vv2.successBg : const Color(0xFFFFF1C7),
            shape: BoxShape.circle,
          ),
          child: Icon(done ? Icons.check_rounded : Icons.schedule_rounded,
              size: 22, color: done ? Vv2.successFg : const Color(0xFF6B4E00)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Vv2.t(16, 22, 700)),
              Text(text, style: Vv2.t(14, 20, 400, color: Vv2.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SumLine extends StatelessWidget {
  final String label, value;
  final bool last;
  const _SumLine(this.label, this.value, {this.last = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Vv2.t(13, 18, 500, color: Vv2.textSecondary)),
          Text(value, style: Vv2.t(16, 22, 700)),
        ],
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
      backgroundColor: Vv2Pastel.cream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Vv2.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration:
                        const BoxDecoration(color: _kRedBg, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, size: 48, color: _kRedFg),
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text('Pagamento recusado',
                      textAlign: TextAlign.center, style: Vv2.t(28, 34, 700)),
                ),
                const SizedBox(height: 20),
                _Box(
                  color: const Color(0xFFFCEFEC),
                  border: const Color(0xFFF3D9D4),
                  child: Text(
                    'Seu cartão foi recusado. Verifique os dados ou tente outro método de pagamento.',
                    style: Vv2.t(16, 24, 500),
                  ),
                ),
                const SizedBox(height: 24),
                VvPillButton(label: 'Tentar novamente', onTap: controller.retryCard),
                const SizedBox(height: 12),
                VvPillButton(
                  label: 'Escolher outro método',
                  kind: VvPillKind.outlined,
                  onTap: () => controller.status.value = PaymentStatus.selecting,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────


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


String _brl(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

/// Escolha de parcelas (aparece só quando o Mercado Pago oferece mais de 1x).
/// Os juros, quando houver, são do tutor e aparecem no total antes de pagar.
class _InstallmentPicker extends GetView<PaymentController> {
  const _InstallmentPicker();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final opts = controller.installmentOptions;
      if (opts.length < 2) return const SizedBox.shrink();
      final sel = controller.selectedInstallments.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              initialValue: opts.any((o) => o.count == sel) ? sel : 1,
              isExpanded: true,
              style: Vv2.t(17, 24, 500),
              decoration: regDecoration('Parcelas'),
              borderRadius: BorderRadius.circular(16),
              items: [
                for (final o in opts)
                  DropdownMenuItem(
                    value: o.count,
                    child: Text(
                        o.count == 1
                            ? '1x de ${_brl(o.total)}'
                            : '${o.count}x de ${_brl(o.each)}'
                                '${(o.total - controller.price) > 0.01 ? ' · total ${_brl(o.total)}' : ' sem juros'}',
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => controller.selectedInstallments.value = v ?? 1,
            ),
            const SizedBox(height: 8),
            Text(
              'Os juros do parcelamento são cobrados pelo cartão e aparecem no total.',
              style: Vv2.t(14, 20, 400, color: Vv2.textSecondary),
            ),
          ],
        ),
      );
    });
  }
}
