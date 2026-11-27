import 'package:flutter/material.dart';
import 'multi_pet_picker.dart';
import 'package:get/get.dart';
import '../../data/models/vet_model.dart';
import '../../theme/app_theme.dart';
import '../../theme/vv2/vv_icons.dart';
import '../../theme/vv2/vv2_tokens.dart';
import '../../widgets/auth_widgets.dart';
import '../auth/register/steps/register_widgets.dart' show regDecoration;
import '../profile/profile_controller.dart';
import '../profile/profile_view.dart' show AddAddressSheet;
import '../../data/models/service_area_model.dart' show normalizeSearchText;
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
      backgroundColor: Vv2Pastel.cream,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Header(),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(Vv2.gutter, 20, Vv2.gutter,
                  24 + MediaQuery.paddingOf(context).bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Pet ──────────────────────────────────────────────────
                  // Qualquer serviço aceita vários animais (o valor é multiplicado
                  // para quem não tem o cadastro "por animal").
                  const _SectionTitle('Quais animais serão atendidos?'),
                  const SizedBox(height: 12),
                  const MultiPetPicker(),

                  const SizedBox(height: 28),

                  // ── Serviço ───────────────────────────────────────────────
                  const _SectionTitle('Quais serviços?'),
                  const SizedBox(height: 4),
                  Text('Você pode marcar mais de um na mesma visita.',
                      style: Vv2.t(15, 22, 400, color: Vv2.textSecondary)),
                  const SizedBox(height: 14),
                  _ServiceSelector(),
                  const MultiPriceSummary(),
                  const ServiceInstructionsNotice(),

                  const SizedBox(height: 28),

                  // ── Data ─────────────────────────────────────────────────
                  const _SectionTitle('Data e Horário'),
                  const SizedBox(height: 12),
                  GetBuilder<SchedulingController>(
                    builder: (c) {
                      final has = c.selectedDate.value != null;
                      return Semantics(
                        button: true,
                        label: has ? 'Data: ${c.formattedDate}' : 'Escolher data',
                        excludeSemantics: true,
                        child: Material(
                          color: Vv2.surface,
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: has ? Vv2.primary : const Color(0xFFE8D5CA),
                              width: has ? 1.5 : 1,
                            ),
                          ),
                          child: InkWell(
                            customBorder: const StadiumBorder(),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: c.firstSelectableDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 60)),
                                selectableDayPredicate: c.isDayAvailable,
                                builder: (ctx, child) => Theme(
                                  data: Theme.of(ctx).copyWith(
                                    colorScheme: const ColorScheme.light(primary: Vv2.primary),
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
                              constraints: const BoxConstraints(minHeight: Vv2.fieldMin),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined,
                                      color: has ? Vv2.onPrimaryContainer : Vv2.outline, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      c.formattedDate,
                                      style: Vv2.t(16, 22, has ? 600 : 400,
                                          color: has ? Vv2.text : Vv2.textSecondary),
                                    ),
                                  ),
                                  const VvIcon(VvFn.forward, size: 20, color: Vv2.outline),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                  Obx(() {
                    final c = controller;
                    final groups = c.timesByPeriod;
                    const icons = {
                      'Manhã': VvFn.periodMorning,
                      'Tarde': VvFn.periodAfternoon,
                      'Noite': VvFn.periodNight,
                    };
                    return Column(
                      children: groups.entries.map((entry) {
                        final period = entry.key;
                        final times = entry.value;
                        final isExpanded = c.expandedPeriod.value == period;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Vv2.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isExpanded
                                  ? Vv2.primary.withValues(alpha: 0.5)
                                  : const Color(0xFFF1E0D6),
                            ),
                          ),
                          child: Column(
                            children: [
                              InkWell(
                                onTap: () => c.togglePeriod(period),
                                child: Container(
                                  constraints: const BoxConstraints(minHeight: Vv2.tapMin + 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Row(
                                    children: [
                                      VvIcon(icons[period] ?? VvFn.periodMorning,
                                          size: 20, color: Vv2.onPrimaryContainer),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(period, style: Vv2.t(16, 22, 700)),
                                      ),
                                      Text(
                                        '${times.length} horário${times.length > 1 ? 's' : ''}',
                                        style: Vv2.t(14, 20, 500, color: Vv2.textSecondary),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        isExpanded
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                        color: Vv2.textSecondary,
                                        size: 22,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isExpanded)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: times.map((t) {
                                      final selected = t == c.selectedTime.value;
                                      final booked = c.isTimeBooked(t);
                                      return Semantics(
                                        button: true,
                                        selected: selected,
                                        label: booked ? '$t, ocupado' : t,
                                        excludeSemantics: true,
                                        child: Material(
                                          color: booked
                                              ? const Color(0xFFF3F1EF)
                                              : selected
                                                  ? Vv2.pressedSurface
                                                  : Vv2.surface,
                                          shape: StadiumBorder(
                                            side: BorderSide(
                                              color: booked
                                                  ? Vv2.divider
                                                  : selected
                                                      ? Vv2.primary
                                                      : const Color(0xFFE8D5CA),
                                              width: selected ? 1.5 : 1,
                                            ),
                                          ),
                                          child: InkWell(
                                            customBorder: const StadiumBorder(),
                                            onTap: () => c.selectTime(t),
                                            child: Container(
                                              constraints: const BoxConstraints(
                                                  minHeight: Vv2.tapMin, minWidth: 84),
                                              padding: const EdgeInsets.symmetric(horizontal: 16),
                                              child: Center(
                                                widthFactor: 1,
                                                heightFactor: 1,
                                                child: Text(
                                                t,
                                                style: Vv2.t(16, 22, selected ? 700 : 600,
                                                        color: booked ? Vv2.outline : Vv2.text)
                                                    .copyWith(
                                                        decoration: booked
                                                            ? TextDecoration.lineThrough
                                                            : null),
                                              ),
                                              ),
                                            ),
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
                  const SizedBox(height: 4),
                  Text(
                    'O profissional vai até você. Selecione onde será o atendimento.',
                    style: Vv2.t(15, 22, 400, color: Vv2.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  _AddressSelector(),

                  const SizedBox(height: 24),

                  // ── Observações ──────────────────────────────────────────
                  TextFormField(
                    controller: controller.notesController,
                    maxLines: 3,
                    minLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    style: Vv2.bodyLarge,
                    decoration: regDecoration('Observações',
                        hint: 'Ex.: meu pet é assustado com barulho (opcional)'),
                  ),

                  const SizedBox(height: 24),
                  Obx(() => VvPillButton(
                        label: 'Confirmar agendamento',
                        loading: controller.isLoading.value,
                        onTap: controller.isLoading.value
                            ? null
                            : () => controller.confirmScheduling(),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cabeçalho em degradê: voltar redondo + "Agendar consulta".
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: Vv2.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Vv2.gutter, 8, Vv2.gutter, 18),
          child: Row(
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
                          child: VvIcon(VvFn.back, size: 22, color: Vv2.onBrand)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text('Agendar consulta', style: Vv2.t(26, 32, 700)),
                ),
              ),
            ],
          ),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...addresses.map((addr) {
            final isSelected = selected?.street == addr.street &&
                selected?.number == addr.number;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Semantics(
                button: true,
                selected: isSelected,
                label: '${addr.label}, ${addr.fullLine}',
                excludeSemantics: true,
                child: Material(
                  color: isSelected ? const Color(0xFFFFF7F2) : Vv2.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? Vv2.primary : const Color(0xFFF1E0D6),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => controller.selectAddress(addr),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(addr.label, style: Vv2.t(16, 22, 700)),
                                const SizedBox(height: 2),
                                Text(
                                  addr.fullLine,
                                  style: Vv2.t(14, 20, 400, color: Vv2.textSecondary),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isSelected)
                            const VvIcon(VvFn.check, size: 22, color: Vv2.primary),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => _showAddAddressSheet(context, profileCtrl),
            style: TextButton.styleFrom(
              foregroundColor: Vv2.primary,
              minimumSize: const Size.fromHeight(Vv2.tapMin),
            ),
            icon: const Icon(Icons.add_rounded, size: 22),
            label: Text('Adicionar novo endereço',
                style: Vv2.t(16, 22, 700, color: Vv2.primary)),
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
    return Semantics(
      header: true,
      child: Text(title, style: Vv2.t(20, 26, 700)),
    );
  }
}

// ─── Service Selector ─────────────────────────────────────────────────────────

class _ServiceSelector extends StatefulWidget {
  @override
  State<_ServiceSelector> createState() => _ServiceSelectorState();
}

class _ServiceSelectorState extends State<_ServiceSelector> {
  final SchedulingController controller = Get.find<SchedulingController>();
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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

    final showSearch = services.length > 5;
    return Obx(() {
      final selected = controller.selectedServices.map((x) => x.name).toSet();
      final q = normalizeSearchText(_query);
      final visible = (!showSearch || q.isEmpty)
          ? services
          : services
              .where((s) => normalizeSearchText('${s.name} ${s.description}').contains(q))
              .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSearch)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar serviço (ex.: vacina)',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('Nenhum serviço encontrado para essa busca.',
                    style: TextStyle(color: AppColors.textMedium, fontSize: 13)),
              ),
            ),
          ...visible.map((s) {
          final isSelected = selected.contains(s.name);
          final note = Vv2.t(14, 20, 400, color: Vv2.textSecondary);
          final card = Padding(
            padding: EdgeInsets.only(bottom: isSelected && controller.animalCount > 1 ? 6 : 12),
            child: Semantics(
              button: true,
              checked: isSelected,
              label: '${s.name}, ${s.priceLabel}',
              child: Material(
                color: isSelected ? const Color(0xFFFFF7F2) : Vv2.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? Vv2.primary : const Color(0xFFF1E0D6),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => controller.toggleService(s),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name, style: Vv2.t(17, 24, 700)),
                              if (s.isPackage) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Vv2.pressedSurface,
                                    borderRadius: BorderRadius.circular(Vv2.rPill),
                                  ),
                                  child: Text('${s.packageSessions} sessões',
                                      style: Vv2.t(13, 18, 700, color: Vv2.onPrimaryContainer)),
                                ),
                              ],
                              if (s.description.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(s.description, style: note),
                              ],
                              const SizedBox(height: 4),
                              Text(s.priceLabel,
                                  style: Vv2.t(17, 24, 700, color: Vv2.primary)),
                              if (s.travel > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '+ Deslocamento R\$ ${s.travel.toStringAsFixed(2).replaceAll('.', ',')} · taxa fixa por visita',
                                    style: note,
                                  ),
                                ),
                              if (controller.vetChargesByKm && s.travelByKm)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '+ Deslocamento calculado pela distância até o seu endereço',
                                    style: note,
                                  ),
                                ),
                              if (s.instructions.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('Tem orientação do veterinário',
                                      style: Vv2.t(14, 20, 700, color: const Color(0xFF6B4E00))),
                                ),
                              if (s.perAnimal)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    s.additionalPrice != null
                                        ? 'Por animal · cada adicional R\$ ${s.additionalPrice!.toStringAsFixed(2).replaceAll('.', ',')}'
                                        : 'Por animal · mesmo valor em cada um',
                                    style: note,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF6B3A20) : Vv2.surface,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                                color: isSelected ? const Color(0xFF6B3A20) : Vv2.outline,
                                width: 1.5),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 20, color: Colors.white)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          if (!isSelected || controller.animalCount <= 1) return card;
          return Column(children: [card, _ServiceAnimalsPicker(service: s)]);
          }),
        ],
      );
    });
  }
}

/// "Para quais animais?" — aparece abaixo do serviço marcado quando o pedido tem mais de um animal.
/// Todos vêm marcados; o tutor tira quem não vai fazer aquele serviço.
class _ServiceAnimalsPicker extends StatelessWidget {
  final VetService service;
  const _ServiceAnimalsPicker({required this.service});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<SchedulingController>();
    final profile = Get.find<ProfileController>();
    return Obx(() {
      final pets = profile.pets;
      final all = (c.selectedPetIndexes.toList()..sort()).where((i) => i < pets.length).toList();
      final mine = c.petsFor(service).toSet();
      final extras = c.extraAnimals.value;
      final k = c.animalsFor(service);
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: Vv2.pressedSurface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Para quais animais? ($k de ${c.animalCount})',
              style: Vv2.t(14, 20, 700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final i in all)
                  _AnimalToggle(
                    species: pets[i].species,
                    label: pets[i].name,
                    selected: mine.contains(i),
                    onTap: () => c.togglePetForService(service, i),
                  ),
              ],
            ),
            if (extras > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Text('Animais sem cadastro neste serviço',
                        style: TextStyle(fontSize: 14, color: Vv2.textSecondary)),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => c.setExtrasForService(service, c.extrasFor(service) - 1),
                    icon: const Icon(Icons.remove_circle_outline, size: 22),
                  ),
                  Text('${c.extrasFor(service)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => c.setExtrasForService(service, c.extrasFor(service) + 1),
                    icon: const Icon(Icons.add_circle_outline, size: 22, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _AnimalToggle extends StatelessWidget {
  final String species, label;
  final bool selected;
  final VoidCallback onTap;
  const _AnimalToggle({required this.species, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PetToggleChip(species: species, label: label, selected: selected, onTap: onTap);
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
