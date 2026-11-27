import 'package:flutter/material.dart';
import '../../data/models/vet_model.dart';
import 'travel_quote.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../theme/vv2/vv_icons.dart';
import '../../theme/vv2/vv2_tokens.dart';
import '../profile/profile_controller.dart';
import 'scheduling_controller.dart';

const _vetvemWhatsapp = '5521982832163';

String _money(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

/// Seleção de vários animais (qualquer serviço): marcar um a um, "Selecionar todos" (respeitando o filtro de espécie) e uma
/// quantidade para animais sem cadastro.
class MultiPetPicker extends StatelessWidget {
  const MultiPetPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<SchedulingController>();
    final profile = Get.find<ProfileController>();
    return Obx(() {
      final pets = profile.pets;
      final hasCats = pets.any((p) => p.species == 'cat');
      final hasDogs = pets.any((p) => p.species == 'dog');
      final filter = c.petFilter.value;
      final shown = <int>[
        for (var i = 0; i < pets.length; i++)
          if (filter == 'all' || pets[i].species == filter) i
      ];
      final allShownSelected =
          shown.isNotEmpty && shown.every(c.selectedPetIndexes.contains);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pets.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (hasCats && hasDogs) ...[
                  _FilterChip('Todos', filter == 'all', () => c.petFilter.value = 'all'),
                  _FilterChip('Gatos', filter == 'cat', () => c.petFilter.value = 'cat'),
                  _FilterChip('Cães', filter == 'dog', () => c.petFilter.value = 'dog'),
                ],
                TextButton(
                  onPressed: shown.isEmpty ? null : c.toggleAllFiltered,
                  style: TextButton.styleFrom(minimumSize: const Size(48, Vv2.tapMin)),
                  child: Text(allShownSelected ? 'Limpar' : 'Selecionar todos',
                      style: Vv2.t(15, 20, 700,
                          color: shown.isEmpty ? Vv2.outline : Vv2.primary)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final i in shown)
                  PetToggleChip(
                    label: pets[i].name,
                    species: pets[i].species,
                    selected: c.selectedPetIndexes.contains(i),
                    onTap: () => c.togglePet(i),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ] else
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Para agendar, cadastre pelo menos um animal no seu Perfil. Assim o veterinário já sabe quem vai atender (nome, espécie, raça e idade).',
                    style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textMedium),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => Get.toNamed(Routes.profile),
                    icon: const Icon(Icons.pets, size: 18),
                    label: const Text('Cadastrar animal no Perfil'),
                  ),
                ],
              ),
            ),
          // Quantidade para quem não cadastrou os animais
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
            decoration: BoxDecoration(
              color: Vv2.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1E0D6)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mais animais sem cadastro', style: Vv2.t(16, 22, 700)),
                      const SizedBox(height: 2),
                      Text('Além dos marcados acima: só a quantidade, sem cadastrar cada um.',
                          style: Vv2.t(14, 20, 400, color: Vv2.textSecondary)),
                    ],
                  ),
                ),
                _RoundStep(
                  icon: Icons.remove_rounded,
                  label: 'Diminuir',
                  onTap: c.extraAnimals.value > 0
                      ? () => c.setExtraAnimals(c.extraAnimals.value - 1)
                      : null,
                ),
                SizedBox(
                  width: 36,
                  child: Text('${c.extraAnimals.value}',
                      textAlign: TextAlign.center, style: Vv2.t(18, 24, 700)),
                ),
                _RoundStep(
                  icon: Icons.add_rounded,
                  label: 'Aumentar',
                  onTap: () => c.setExtraAnimals(c.extraAnimals.value + 1),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) => _Pill(label: label, selected: selected, onTap: onTap);
}

/// Pílula de escolha (alvo de 48): fundo claro + borda quando marcada.
class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  const _Pill({required this.label, required this.selected, required this.onTap, this.leading});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? Vv2.pressedSurface : Vv2.surface,
        shape: StadiumBorder(
          side: BorderSide(
              color: selected ? Vv2.primary : const Color(0xFFE8D5CA),
              width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: Vv2.tapMin, minWidth: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 6)],
                Flexible(
                  child: Text(label,
                      style: Vv2.t(15, 20, selected ? 700 : 600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pet marcável (nome + ícone da espécie). Usado na lista de animais e em
/// "Para quais animais?" de cada serviço.
class PetToggleChip extends StatelessWidget {
  final String label, species;
  final bool selected;
  final VoidCallback onTap;
  const PetToggleChip(
      {super.key,
      required this.label,
      required this.species,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sp = species == 'cat' ? 'Gato' : species == 'dog' ? 'Cão' : 'Pet';
    return _Pill(
      label: label,
      selected: selected,
      onTap: onTap,
      leading: VvIcon.species(species, sp, size: 22, color: Vv2.onPrimaryContainer),
    );
  }
}

class _RoundStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _RoundStep({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      style: IconButton.styleFrom(
        backgroundColor: Vv2.pressedSurface,
        disabledBackgroundColor: const Color(0xFFF3F1EF),
      ),
      icon: Icon(icon, size: 22, color: onTap == null ? Vv2.outline : Vv2.onPrimaryContainer),
    );
  }
}

/// Resumo do total do pedido por animal + aviso acima do limite.
class MultiPriceSummary extends StatelessWidget {
  const MultiPriceSummary({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<SchedulingController>();
    return Obx(() {
      final list = c.selectedServices.toList();
      final n = c.animalCount;
      // Com 1 animal em serviço comum não há o que somar: o resumo some.
      final byKm = c.usesTravelByKm;
      final fixed = c.fixedTravel;
      if (list.isEmpty ||
          (list.length == 1 && !list.first.perAnimal && n <= 1 && fixed <= 0 && !byKm)) {
        return const SizedBox.shrink();
      }
      String lineOf(VetService s) {
        final n = c.animalsFor(s);
        final extra = s.perAnimal ? (s.additionalPrice ?? s.price) : s.price;
        final body = n <= 1
            ? _money(s.price)
            : (extra == s.price
                ? '$n × ${_money(s.price)}'
                : '${_money(s.price)} + ${n - 1} × ${_money(extra)}');
        return list.length > 1 ? '${s.name}: $body' : (n <= 1 ? '1 animal: $body' : '$n animais: $body');
      }
      final tooMany = n > SchedulingController.maxAnimalsBeforeQuote;
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Vv2.pressedSurface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1D3C2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in list)
              Text(lineOf(s), style: Vv2.t(14, 20, 400, color: Vv2.textSecondary)),
            if (!byKm && fixed > 0)
              Text('Deslocamento (taxa fixa por visita): ${_money(fixed)}',
                  style: Vv2.t(14, 20, 400, color: Vv2.textSecondary)),
            if (byKm) _TravelLine(c.travelQuote.value),
            const SizedBox(height: 6),
            Text('Total: ${_money(c.totalPrice)}',
                style: Vv2.t(20, 26, 700, color: Vv2.onPrimaryContainer)),
            if (tooMany) ...[
              const SizedBox(height: 10),
              Text(
                'Para $n animais, vale pedir um orçamento: o tempo e a logística podem mudar o valor. Você pode seguir com o pedido normalmente ou falar com a gente.',
                style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textMedium),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(
                      'https://wa.me/$_vetvemWhatsapp?text=${Uri.encodeComponent('Olá! Quero agendar "${c.serviceLabel}" para $n animais e gostaria de um orçamento.')}'),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.chat_outlined, size: 18),
                label: const Text('Pedir orçamento no WhatsApp'),
              ),
            ],
          ],
        ),
      );
    });
  }
}

/// Orientações do profissional para o serviço escolhido, mostradas ANTES de pagar
/// (ex.: "jejum de 6 horas"), para o tutor saber como se preparar.
class ServiceInstructionsNotice extends StatelessWidget {
  const ServiceInstructionsNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<SchedulingController>();
    return Obx(() {
      final withText = c.selectedServices.where((x) => x.instructions.isNotEmpty).toList();
      if (withText.isEmpty) return const SizedBox.shrink();
      final many = c.selectedServices.length > 1;
      final text = withText.map((x) => many ? '${x.name}: ${x.instructions}' : x.instructions).join('\n');
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1C7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Orientação do veterinário',
                style: Vv2.t(15, 20, 700, color: const Color(0xFF6B4E00))),
            const SizedBox(height: 4),
            Text(text, style: Vv2.t(15, 22, 400, color: const Color(0xFF6B4E00))),
          ],
        ),
      );
    });
  }
}

/// Linha do deslocamento por km no resumo do pedido (calculando / valor / aviso).
class _TravelLine extends StatelessWidget {
  final TravelQuote q;
  const _TravelLine(this.q);

  @override
  Widget build(BuildContext context) {
    final base = Vv2.t(14, 20, 400, color: Vv2.textSecondary);
    if (q.isLoading) {
      return Text('Deslocamento: calculando pelo seu endereço…', style: base);
    }
    if (q.isOk) {
      final km = q.km.toStringAsFixed(1).replaceAll('.', ',');
      final how = q.roundTrip ? 'ida e volta' : 'só ida';
      return Text(
          'Deslocamento ($km km, $how): ${_money(q.fee)}${q.capped ? ' · valor máximo' : ''}',
          style: base);
    }
    if (q.state == 'idle') {
      return Text('Deslocamento: escolha o endereço para calcular.', style: base);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(q.message,
          style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFFB91C1C))),
    );
  }
}
