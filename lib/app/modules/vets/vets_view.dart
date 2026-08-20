import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../theme/app_theme.dart';
import '../../data/models/vet_model.dart';
import '../../widgets/shimmer.dart';
import '../home/home_controller.dart';
import 'vets_controller.dart';

class VetsView extends GetView<VetsController> {
  const VetsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
        children: [
          _VetsHeader(),
          Expanded(
            child: ColoredBox(
              color: AppColors.background,
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.textDark,
                  decoration: TextDecoration.none,
                ),
                child: Obx(() {
              if (controller.isLoading.value) {
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, __) => const VetCardSkeleton(),
                );
              }
              final vets = controller.filteredVets;
              final filterActive = controller.filterByArea.value;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      selected: filterActive,
                      onSelected: (_) => controller.toggleAreaFilter(),
                      avatar: filterActive
                          ? null
                          : const Icon(Icons.location_on_outlined,
                              size: 16, color: AppColors.textMedium),
                      label: Text(
                        filterActive
                            ? 'Atendem: ${controller.tutorAddressLabel.value}'
                            : 'Atendem meu endereço',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Poppins',
                          fontWeight:
                              filterActive ? FontWeight.w600 : FontWeight.w500,
                          color: filterActive
                              ? AppColors.primary
                              : AppColors.textMedium,
                        ),
                      ),
                      backgroundColor: Colors.white,
                      selectedColor: AppColors.primary.withValues(alpha: 0.12),
                      checkmarkColor: AppColors.primary,
                      side: BorderSide(
                        color: filterActive
                            ? AppColors.primary
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                  ),
                  if (vets.isEmpty) ...[
                    const SizedBox(height: 24),
                    _EmptyState(filterActive: filterActive),
                  ] else ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${vets.length} ${vets.length != 1 ? 'profissionais disponíveis' : 'profissional disponível'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMedium,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      GetBuilder<VetsController>(
                        builder: (c) => GestureDetector(
                          onTap: () => _showSortSheet(context, c),
                          child: Row(
                            children: [
                              const Icon(Icons.sort_rounded,
                                  size: 16, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                _sortLabel(c.sortIndex.value),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...vets.map((v) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: VetCard(vet: v),
                      )),
                  ],
                ],
              );
            }),
              ),
            ),
          ),
        ],
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _VetsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = Get.find<VetsController>();
    return Material(
      color: AppColors.primary,
      textStyle: const TextStyle(
        fontFamily: 'Poppins',
        decoration: TextDecoration.none,
        color: Colors.white,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Título + botão mapa
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 20),
                    onPressed: () => Get.find<HomeController>().changeTab(0),
                  ),
                  Expanded(
                    child: GetBuilder<VetsController>(
                      builder: (c) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.selectedSpecialty.value.isEmpty
                                ? 'Buscar profissional'
                                : c.selectedSpecialty.value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const Text(
                            'Profissionais perto de você',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Search + filtros
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  TextField(
                    controller: c.searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome ou especialidade...',
                      hintStyle: const TextStyle(
                          color: AppColors.textLight, fontSize: 13),
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.textLight, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GetBuilder<VetsController>(
                    builder: (c) => SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: c.specialties.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final s = c.specialties[i];
                          final selected =
                              (s == 'Todos' && c.selectedSpecialty.value.isEmpty) ||
                              s == c.selectedSpecialty.value;
                          return GestureDetector(
                            onTap: () => c.selectSpecialty(s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Text(
                                  s,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? AppColors.primary
                                        : Colors.white,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
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

String _sortLabel(int index) {
  switch (index) {
    case 1: return 'Avaliação';
    case 2: return 'Atendimentos';
    case 3: return 'Menor preço';
    default: return 'Relevância';
  }
}

void _showSortSheet(BuildContext context, VetsController c) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ordenar por',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          ...[
            (0, Icons.auto_awesome_rounded, 'Relevância', 'Score combinado: avaliação + atendimentos + cancelamentos'),
            (1, Icons.star_rounded, 'Melhor avaliados', 'Ordenado pela nota média dos clientes'),
            (2, Icons.check_circle_outline_rounded, 'Mais atendimentos', 'Profissionais com mais consultas concluídas'),
            (3, Icons.attach_money_rounded, 'Menor preço', 'Do serviço mais acessível para o mais caro'),
          ].map((item) {
            final (idx, icon, label, sub) = item;
            final selected = c.sortIndex.value == idx;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon,
                color: selected ? AppColors.primary : AppColors.textMedium,
                size: 22,
              ),
              title: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppColors.primary : AppColors.textDark,
                ),
              ),
              subtitle: Text(sub,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textMedium,
                ),
              ),
              trailing: selected
                ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 20)
                : null,
              onTap: () {
                c.setSort(idx);
                Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    ),
  );
}


// ─── Vet Card ─────────────────────────────────────────────────────────────────

class VetCard extends GetView<VetsController> {
  final VetModel vet;
  const VetCard({super.key, required this.vet});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => controller.openVetDetail(vet),
      child: Opacity(
        opacity: vet.isAvailable ? 1.0 : 0.55,
        child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            _VetAvatar(vet: vet, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          vet.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!vet.isAvailable) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.textLight.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Pausado',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMedium),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: AppColors.warning, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        '${vet.rating}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          vet.specialty,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMedium),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (vet.hasMultipleServices)
                  const Text(
                    'a partir de',
                    style: TextStyle(fontSize: 10, color: AppColors.textLight),
                  ),
                Text(
                  'R\$ ${vet.startingPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 16,
                  ),
                ),
                Text(
                  vet.hasMultipleServices ? 'por serviço' : 'por visita',
                  style: const TextStyle(fontSize: 10, color: AppColors.textLight),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool filterActive;
  const _EmptyState({this.filterActive = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: AppColors.textLight),
            const SizedBox(height: 16),
            Text(
              filterActive
                  ? 'Nenhum profissional atende sua região ainda.\n'
                      'Toque no filtro acima para ver todos.'
                  : 'Nenhum profissional encontrado',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class _VetAvatar extends StatelessWidget {
  final VetModel vet;
  final double size;
  const _VetAvatar({required this.vet, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final photo = vet.photoBase64;
    final url = vet.imageUrl;
    ImageProvider? image;
    if (photo.isNotEmpty) {
      image = MemoryImage(base64Decode(photo.split(',').last));
    } else if (url.isNotEmpty) {
      image = NetworkImage(url);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        image: image != null
            ? DecorationImage(image: image, fit: BoxFit.cover)
            : null,
      ),
      child: image == null
          ? Icon(Icons.person, color: AppColors.primary, size: size * 0.5)
          : null,
    );
  }
}
