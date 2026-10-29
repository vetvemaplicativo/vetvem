import 'package:flutter/material.dart';
import 'travel_quote.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
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
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (hasCats && hasDogs) ...[
                        _FilterChip('Todos', filter == 'all', () => c.petFilter.value = 'all'),
                        _FilterChip('Gatos', filter == 'cat', () => c.petFilter.value = 'cat'),
                        _FilterChip('Cães', filter == 'dog', () => c.petFilter.value = 'dog'),
                      ],
                    ],
                  ),
                ),
                InkWell(
                  onTap: shown.isEmpty ? null : c.toggleAllFiltered,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Text(allShownSelected ? 'Limpar' : 'Selecionar todos',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: shown.isEmpty ? AppColors.textLight : AppColors.primary)),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final i in shown)
                  _PetChip(
                    name: pets[i].name,
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mais animais sem cadastro',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      SizedBox(height: 2),
                      Text('Além dos marcados acima: só a quantidade, sem cadastrar cada um.',
                          style: TextStyle(fontSize: 11, color: AppColors.textMedium)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: c.extraAnimals.value > 0
                      ? () => c.setExtraAnimals(c.extraAnimals.value - 1)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('${c.extraAnimals.value}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                IconButton(
                  onPressed: () => c.setExtraAnimals(c.extraAnimals.value + 1),
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
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
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? AppColors.primary : const Color(0xFFE5E7EB)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textMedium)),
        ),
      );
}

class _PetChip extends StatelessWidget {
  final String name, species;
  final bool selected;
  final VoidCallback onTap;
  const _PetChip(
      {required this.name,
      required this.species,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final emoji = species == 'cat' ? '🐱' : species == 'dog' ? '🐶' : '🐾';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE5E7EB),
              width: selected ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(name,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.primary : AppColors.textDark)),
            if (selected) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check_circle, size: 16, color: AppColors.primary),
            ],
          ],
        ),
      ),
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
      final s = c.selectedService.value;
      final n = c.animalCount;
      // Com 1 animal em serviço comum não há o que somar: o resumo some.
      final byKm = c.usesTravelByKm;
      if (s == null || (!s.perAnimal && n <= 1 && s.travel <= 0 && !byKm)) return const SizedBox.shrink();
      final extra = s.perAnimal ? (s.additionalPrice ?? s.price) : s.price;
      final line = n <= 1
          ? '1 animal: ${_money(s.price)}'
          : (extra == s.price
              ? '$n animais: $n × ${_money(s.price)}'
              : '$n animais: ${_money(s.price)} + ${n - 1} × ${_money(extra)}');
      final tooMany = n > SchedulingController.maxAnimalsBeforeQuote;
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line, style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
            if (s.travel > 0)
              Text('Deslocamento (taxa fixa por visita): ${_money(s.travel)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
            if (byKm) _TravelLine(c.travelQuote.value),
            const SizedBox(height: 2),
            Text('Total: ${_money(c.totalPrice)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
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
                      'https://wa.me/$_vetvemWhatsapp?text=${Uri.encodeComponent('Olá! Quero agendar "${s.name}" para $n animais e gostaria de um orçamento.')}'),
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
      final s = c.selectedService.value;
      if (s == null || s.instructions.isEmpty) return const SizedBox.shrink();
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚠️ Orientação do veterinário para este serviço',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
            const SizedBox(height: 4),
            Text(s.instructions,
                style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFFB45309))),
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
    const base = TextStyle(fontSize: 12, color: AppColors.textMedium);
    if (q.isLoading) {
      return const Text('Deslocamento: calculando pelo seu endereço…', style: base);
    }
    if (q.isOk) {
      final km = q.km.toStringAsFixed(1).replaceAll('.', ',');
      final how = q.roundTrip ? 'ida e volta' : 'só ida';
      return Text(
          'Deslocamento ($km km, $how): ${_money(q.fee)}${q.capped ? ' · valor máximo' : ''}',
          style: base);
    }
    if (q.state == 'idle') {
      return const Text('Deslocamento: escolha o endereço para calcular.', style: base);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(q.message,
          style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFFB91C1C))),
    );
  }
}
