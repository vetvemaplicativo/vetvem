import 'package:flutter/material.dart';
import 'multi_pet_picker.dart';
import 'package:get/get.dart';
import '../../theme/app_theme.dart';
import '../profile/profile_controller.dart';
import '../profile/profile_view.dart' show AddAddressSheet;
import '../vets/vets_controller.dart';
import 'scheduling_controller.dart';

class SchedulingView extends GetView<SchedulingController> {
  const SchedulingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() => controller.isConfirmed.value
        ? const _SuccessScreen()
        : _SchedulingForm());
  }
}

class _SchedulingForm extends GetView<SchedulingController> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Agendar consulta'),
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
            // ── Pet ──────────────────────────────────────────────────
            // Qualquer serviço aceita vários animais (o valor é multiplicado
            // para quem não tem o cadastro "por animal").
            const _SectionTitle('Quais animais serão atendidos?'),
            const SizedBox(height: 12),
            const MultiPetPicker(),

            const SizedBox(height: 24),

            // ── Serviço ───────────────────────────────────────────────
            const _SectionTitle('Qual serviço?'),
            const SizedBox(height: 12),
            _ServiceSelector(),
            const MultiPriceSummary(),
            const ServiceInstructionsNotice(),

            const SizedBox(height: 24),

            // ── Data ─────────────────────────────────────────────────
            const _SectionTitle('Data e Horário'),
            const SizedBox(height: 12),
            GetBuilder<SchedulingController>(
              builder: (c) => GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: c.firstSelectableDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                    selectableDayPredicate: c.isDayAvailable,
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: const ColorScheme.light(primary: AppColors.primary),
                      ),
                      child: child!,
                    ),
                  );
                  if (date != null) {
                    c.selectDate(date);
                    c.update();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: c.selectedDate.value != null
                          ? AppColors.primary
                          : const Color(0xFFE5E7EB),
                      width: c.selectedDate.value != null ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: c.selectedDate.value != null
                            ? AppColors.primary
                            : AppColors.textLight,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        c.formattedDate,
                        style: TextStyle(
                          color: c.selectedDate.value != null
                              ? AppColors.textDark
                              : AppColors.textLight,
                          fontWeight: c.selectedDate.value != null
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios,
                          size: 14, color: AppColors.textLight),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Text(
              'Horário',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),
            Obx(() {
              final c = controller;
              final groups = c.timesByPeriod;
              const icons = {
                'Manhã': Icons.wb_sunny_outlined,
                'Tarde': Icons.wb_cloudy_outlined,
                'Noite': Icons.nights_stay_outlined,
              };
              return Column(
                children: groups.entries.map((entry) {
                  final period = entry.key;
                  final times = entry.value;
                  final isExpanded = c.expandedPeriod.value == period;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isExpanded
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Cabeçalho do período
                        InkWell(
                          onTap: () {
                            c.togglePeriod(period);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Icon(icons[period],
                                    size: 18, color: AppColors.primary),
                                const SizedBox(width: 10),
                                Text(
                                  period,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${times.length} horário${times.length > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMedium),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: AppColors.textMedium,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Horários (visíveis ao expandir)
                        if (isExpanded)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: times.map((t) {
                                final selected = t == c.selectedTime.value;
                                final booked = c.isTimeBooked(t);
                                return GestureDetector(
                                  onTap: () => c.selectTime(t),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: booked
                                          ? const Color(0xFFF3F4F6)
                                          : selected
                                              ? AppColors.primary
                                              : const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: booked
                                            ? const Color(0xFFE5E7EB)
                                            : selected
                                                ? AppColors.primary
                                                : const Color(0xFFE5E7EB),
                                      ),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Text(
                                          t,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: booked
                                                ? const Color(0xFFD1D5DB)
                                                : selected
                                                    ? Colors.white
                                                    : AppColors.textDark,
                                          ),
                                        ),
                                        if (booked)
                                          Positioned.fill(
                                            child: Center(
                                              child: Container(
                                                height: 1.5,
                                                color: const Color(0xFFD1D5DB),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              );
            }),

            const SizedBox(height: 24),

            // ── Endereço ─────────────────────────────────────────────
            const _SectionTitle('Endereço para atendimento'),
            const SizedBox(height: 8),
            const Text(
              'O profissional vai até você — selecione onde será o atendimento.',
              style: TextStyle(fontSize: 12, color: AppColors.textMedium),
            ),
            const SizedBox(height: 12),
            _AddressSelector(),

            const SizedBox(height: 24),

            // ── Observações ──────────────────────────────────────────
            const _SectionTitle('Observações'),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller.notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Ex: meu pet é assustado com barulho... (opcional)',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 48),
                  child: Icon(Icons.note_outlined, color: AppColors.textLight),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const SizedBox(height: 20),
            Obx(() => ElevatedButton(
              onPressed: controller.isLoading.value ? null : () => controller.confirmScheduling(),
              child: controller.isLoading.value
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Confirmar agendamento'),
            )),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Address Selector ────────────────────────────────────────────────────────

class _AddressSelector extends GetView<SchedulingController> {
  @override
  Widget build(BuildContext context) {
    final profileCtrl = Get.find<ProfileController>();
    return Obx(() {
      final addresses = profileCtrl.addresses;
      final selected = controller.selectedAddress.value;
      return Column(
        children: [
          ...addresses.map((addr) {
            final isSelected = selected?.street == addr.street &&
                selected?.number == addr.number;
            return GestureDetector(
              onTap: () => controller.selectAddress(addr),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : const Color(0xFFE5E7EB),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        addr.label == 'Casa'
                            ? Icons.home_outlined
                            : addr.label == 'Trabalho'
                                ? Icons.work_outline_rounded
                                : Icons.location_on_outlined,
                        color: isSelected ? AppColors.primary : AppColors.textMedium,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            addr.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isSelected ? AppColors.primary : AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            addr.fullLine,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMedium),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary, size: 22),
                  ],
                ),
              ),
            );
          }),
          // Botão adicionar novo endereço
          GestureDetector(
            onTap: () => _showAddAddressSheet(context, profileCtrl),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  style: BorderStyle.solid,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_location_alt_outlined,
                      color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Adicionar novo endereço',
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

  // Mesmo formulário do Perfil: o CEP vem primeiro e preenche rua, bairro, cidade e UF.
  void _showAddAddressSheet(BuildContext context, ProfileController profileCtrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddAddressSheet(
        controller: profileCtrl,
        onSaved: controller.selectAddress,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      ),
    );
  }
}

// ─── Service Selector ─────────────────────────────────────────────────────────

class _ServiceSelector extends GetView<SchedulingController> {
  @override
  Widget build(BuildContext context) {
    final vet = Get.find<VetsController>().selectedVet.value;
    final services = vet?.validServices ?? [];

    if (services.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Text('Nenhum serviço cadastrado',
            style: TextStyle(color: AppColors.textLight)),
      );
    }

    return Obx(() {
      final selected = controller.selectedService.value;
      return Column(
        children: services.map((s) {
          final isSelected = selected?.name == s.name;
          return GestureDetector(
            onTap: () => controller.selectService(s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.primary : const Color(0xFFE5E7EB),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Ícone de pacote ou serviço
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      s.isPackage
                          ? Icons.card_giftcard_outlined
                          : Icons.medical_services_outlined,
                      color: isSelected ? AppColors.primary : AppColors.textMedium,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textDark,
                                ),
                              ),
                            ),
                            if (s.isPackage)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${s.packageSessions} sessões',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.description,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMedium),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.priceLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        if (s.travel > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              '+ Deslocamento R\$ ${s.travel.toStringAsFixed(2).replaceAll('.', ',')} (taxa fixa por visita)',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textMedium),
                            ),
                          ),
                        if (controller.vetChargesByKm && s.travelByKm)
                          const Padding(
                            padding: EdgeInsets.only(top: 3),
                            child: Text(
                              '+ Deslocamento calculado pela distância até o seu endereço',
                              style: TextStyle(fontSize: 11, color: AppColors.textMedium),
                            ),
                          ),
                        if (s.instructions.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              '⚠️ Tem orientação do veterinário (veja abaixo)',
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFFB45309)),
                            ),
                          ),
                        if (s.perAnimal)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              s.additionalPrice != null
                                  ? 'Por animal · cada adicional R\$ ${s.additionalPrice!.toStringAsFixed(2).replaceAll('.', ',')}'
                                  : 'Por animal · mesmo valor em cada um',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textMedium),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    color: isSelected ? AppColors.primary : AppColors.textLight,
                    size: 22,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    });
  }
}

// ─── Success Screen ───────────────────────────────────────────────────────────

class _SuccessScreen extends GetView<SchedulingController> {
  const _SuccessScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            children: [
              // Ícone principal
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                'Agendamento Enviado!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Seu agendamento foi recebido com sucesso.\nVeja o que acontece agora:',
                style: TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // Steps do fluxo
              _SuccessStep(
                icon: Icons.calendar_today_rounded,
                color: AppColors.primary,
                title: 'Agendamento enviado',
                subtitle: 'O profissional recebeu a solicitação',
                done: true,
                isLast: false,
              ),
              _SuccessStep(
                icon: Icons.person_search_rounded,
                color: const Color(0xFFF59E0B),
                title: 'Aguardando confirmação',
                subtitle: 'O profissional irá aceitar ou recusar',
                done: false,
                isLast: false,
              ),
              _SuccessStep(
                icon: Icons.notifications_active_rounded,
                color: const Color(0xFF8B5CF6),
                title: 'Você será notificado',
                subtitle: 'Receberá um aviso quando ele confirmar',
                done: false,
                isLast: false,
              ),
              _SuccessStep(
                icon: Icons.payment_rounded,
                color: const Color(0xFF22C55E),
                title: 'Efetue o pagamento',
                subtitle: 'PIX ou cartão — rápido e seguro',
                done: false,
                isLast: false,
              ),
              _SuccessStep(
                icon: Icons.pets_rounded,
                color: AppColors.primary,
                title: 'Consulta garantida! 🐾',
                subtitle: 'Seu pet estará em boas mãos',
                done: false,
                isLast: true,
              ),

              const SizedBox(height: 28),

              // Dica de pagamento
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  children: [
                    Text('💡', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'O pagamento só é cobrado após a confirmação do profissional. Aceitamos PIX e cartão de crédito.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Get.offAllNamed('/home'),
                icon: const Icon(Icons.home_rounded, size: 20),
                label: const Text('Ir para início'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Get.offAllNamed('/home', arguments: {'tab': 2}),
                icon: Icon(Icons.list_alt_rounded, size: 18, color: AppColors.primary),
                label: Text('Ver minhas consultas',
                    style: TextStyle(color: AppColors.primary)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessStep extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool done;
  final bool isLast;

  const _SuccessStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: done ? color : color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: done ? Colors.white : color, size: 22),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                margin: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.4), color.withValues(alpha: 0.1)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: done ? color : AppColors.textDark,
                    )),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
                SizedBox(height: isLast ? 0 : 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
