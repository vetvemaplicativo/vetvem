import '../home/region_picker_sheet.dart';
import 'dart:convert';
import '../../services/analytics_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../theme/app_theme.dart';
import '../../theme/vv2/vv_icons.dart';
import '../../theme/vv2/vv2_tokens.dart';
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
              color: Vv2Pastel.cream,
              child: DefaultTextStyle(
                style: Vv2.bodyLarge.copyWith(
                  decoration: TextDecoration.none,
                ),
                child: Obx(() {
              if (controller.isLoading.value) {
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      Vv2.gutter, Vv2.gutter, Vv2.gutter, 20),
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, __) => const VetCardSkeleton(),
                );
              }
              final vets = controller.filteredVets;
              final filterActive = controller.filterByArea.value;
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                    Vv2.gutter, 0, Vv2.gutter, 20),
                children: [
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _AreaPill(
                        active: filterActive,
                        label: filterActive
                            ? 'Atendem: ${controller.tutorAddressLabel.value}'
                            : (controller.isGuest
                                ? 'Escolher minha cidade'
                                : 'Atendem meu endereço'),
                        onTap: () => controller.isGuest
                            ? RegionPickerSheet.show()
                            : controller.toggleAreaFilter(),
                      ),
                      if (vets.isNotEmpty)
                        GetBuilder<VetsController>(
                          builder: (c) => _SortPill(
                            label: _sortLabel(c.sortIndex.value),
                            onTap: () => _showSortSheet(context, c),
                          ),
                        ),
                    ],
                  ),
                  if (vets.isEmpty) ...[
                    const SizedBox(height: 24),
                    _EmptyState(filterActive: filterActive),
                  ] else ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '${vets.length} ${vets.length != 1 ? 'profissionais disponíveis' : 'profissional disponível'}',
                      style: Vv2.bodyMedium,
                    ),
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

class _AreaPill extends StatelessWidget {
  final bool active;
  final String label;
  final VoidCallback onTap;
  const _AreaPill(
      {required this.active, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Vv2.pressedSurface,
        borderRadius: BorderRadius.circular(Vv2.rPill),
        child: InkWell(
          borderRadius: BorderRadius.circular(Vv2.rPill),
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(
                minHeight: Vv2.tapMin,
                maxWidth: MediaQuery.sizeOf(context).width - 2 * Vv2.gutter),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const VvIcon(VvFn.location, size: 20, color: Vv2.onBrand),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Vv2.t(14, 20, 700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SortPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SortPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ordenar por: $label',
      excludeSemantics: true,
      child: Material(
        color: Vv2.surface,
        borderRadius: BorderRadius.circular(Vv2.rPill),
        child: InkWell(
          borderRadius: BorderRadius.circular(Vv2.rPill),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: Vv2.tapMin),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const VvIcon(VvFn.sort, size: 20, color: Vv2.onBrand),
                const SizedBox(width: 8),
                Text(label, style: Vv2.t(14, 20, 700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _VetsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = Get.find<VetsController>();
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: Vv2.searchGradient),
      child: Material(
        type: MaterialType.transparency,
        textStyle: Vv2.bodyLarge.copyWith(decoration: TextDecoration.none),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                Vv2.gutter, 12, Vv2.gutter, Vv2.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Voltar',
                      excludeSemantics: true,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Get.find<HomeController>().changeTab(0),
                        child: Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                              color: Vv2.surface, shape: BoxShape.circle),
                          child: const VvIcon(VvFn.back,
                              size: 24, color: Vv2.onBrand),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GetBuilder<VetsController>(
                        builder: (c) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.selectedSpecialty.value.isEmpty
                                  ? 'Buscar profissional'
                                  : c.selectedSpecialty.value,
                              style: Vv2.t(26, 32, 700),
                            ),
                            Text('Profissionais perto de você',
                                style: Vv2.bodyMedium
                                    .copyWith(color: Vv2.onBrand)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: c.searchController,
                  style: Vv2.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome ou especialidade...',
                    hintStyle: Vv2.t(15, 20, 400, color: Vv2.textSecondary),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(14),
                      child: VvIcon(VvFn.search, size: 24, color: Vv2.onBrand),
                    ),
                    filled: true,
                    fillColor: Vv2.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    constraints:
                        const BoxConstraints(minHeight: Vv2.fieldMin),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Vv2.rPill),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                GetBuilder<VetsController>(
                  builder: (c) => SizedBox(
                    height: Vv2.tapMin,
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
                        return Semantics(
                          button: true,
                          selected: selected,
                          label: s,
                          excludeSemantics: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => c.selectSpecialty(s),
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                constraints:
                                    const BoxConstraints(minHeight: 32),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Vv2.pressedSurface
                                      : Colors.transparent,
                                  borderRadius:
                                      BorderRadius.circular(Vv2.rPill),
                                  border: Border.all(
                                      color: selected
                                          ? Colors.transparent
                                          : Vv2.onBrand,
                                      width: 1),
                                ),
                                child: Text(s,
                                    style:
                                        Vv2.t(14, 20, selected ? 700 : 600)),
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
    backgroundColor: Vv2.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Vv2.rOverlay)),
    ),
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Vv2.gutter, 12, Vv2.gutter, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Vv2.brand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Ordenar por', style: Vv2.titleLarge),
            const SizedBox(height: 8),
            ...[
              (0, VvFn.sortRelevance, 'Relevância', 'Score combinado: avaliação + atendimentos + cancelamentos'),
              (1, VvFn.sortRating, 'Melhor avaliados', 'Ordenado pela nota média dos clientes'),
              (2, VvFn.sortVolume, 'Mais atendimentos', 'Profissionais com mais consultas concluídas'),
              (3, VvFn.sortPrice, 'Menor preço', 'Do serviço mais acessível para o mais caro'),
            ].map((item) {
              final (idx, icon, label, sub) = item;
              final selected = c.sortIndex.value == idx;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                minVerticalPadding: 8,
                leading: VvIcon(icon,
                    color: selected ? Vv2.primary : Vv2.textSecondary,
                    size: 24),
                title: Text(label,
                    style: Vv2.t(16, 24, selected ? 700 : 600,
                        color: selected ? Vv2.primary : Vv2.text)),
                subtitle: Text(sub, style: Vv2.bodySmall),
                trailing: selected
                    ? const VvIcon(VvFn.check, size: 20, color: Vv2.primary)
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
    ),
  );
}


// ─── Vet Card ─────────────────────────────────────────────────────────────────

class VetCard extends GetView<VetsController> {
  final VetModel vet;
  const VetCard({super.key, required this.vet});

  @override
  Widget build(BuildContext context) {
    final price = 'R\$ ${vet.startingPrice.toStringAsFixed(0)}';
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () => controller.openVetDetail(vet),
        child: Opacity(
          opacity: vet.isAvailable ? 1.0 : 0.55,
          child: Container(
            padding: const EdgeInsets.all(Vv2.gutter),
            decoration: BoxDecoration(
              color: Vv2.surface,
              borderRadius: BorderRadius.circular(Vv2.rOverlay),
              boxShadow: Vv2.cardShadow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar com a nota logo abaixo
                Column(
                  children: [
                    _VetAvatar(vet: vet, size: 56),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBC2),
                        borderRadius: BorderRadius.circular(Vv2.rPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const VvIcon(VvFn.ratingBadge,
                              size: 14, color: Vv2.onBrand),
                          const SizedBox(width: 3),
                          Text('${vet.rating}', style: Vv2.t(13, 18, 700)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(vet.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Vv2.t(17, 24, 700)),
                          ),
                          if (!vet.isAvailable) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Vv2.secondaryContainer,
                                borderRadius: BorderRadius.circular(Vv2.rPill),
                              ),
                              child: Text('Pausado',
                                  style: Vv2.t(12, 18, 600,
                                      color: Vv2.textSecondary)),
                            ),
                          ],
                        ],
                      ),
                      Text(vet.specialty,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Vv2.bodyMedium),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Vv2.pressedSurface,
                          borderRadius: BorderRadius.circular(Vv2.rCard),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                vet.hasMultipleServices
                                    ? 'A partir de $price'
                                    : price,
                                style: Vv2.price),
                            Text(
                                vet.hasMultipleServices
                                    ? 'por serviço'
                                    : 'por visita',
                                style: Vv2.t(12, 16, 600,
                                    color: Vv2.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatefulWidget {
  final bool filterActive;
  const _EmptyState({this.filterActive = false});

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState> {
  static const _whatsapp = '5521982832163';
  bool _joined = false;
  bool _joining = false;

  VetsController get _c => Get.find<VetsController>();
  bool get _hasRegion => _c.tutorUf.length == 2 && _c.tutorCity.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Só registra quando a busca vazia é de região (não de texto digitado).
    if (_hasRegion && widget.filterActive) {
      Get.find<AnalyticsService>().logSearchNoResults(_c.tutorUf, _c.tutorCity);
      _recordDemand();
    }
  }

  // Registro automático (1 por pessoa e cidade) para mapear onde há demanda sem
  // cobertura. Id fixo: a 2ª gravação é recusada pelas regras e ignorada aqui.
  Future<void> _recordDemand() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final city = _c.tutorCity.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    try {
      await FirebaseFirestore.instance
          .collection('waitlist_regiao')
          .doc('busca_${uid}_${_c.tutorUf}_$city')
          .set({
        'uf': _c.tutorUf,
        'cidade': _c.tutorCity,
        'contato': 'uid:$uid',
        'origem': 'app_tutor_busca_vazia',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _join() async {
    final user = FirebaseAuth.instance.currentUser;
    final contact = user?.email ?? '';
    if (user == null || contact.length < 5 || !_hasRegion) return;
    setState(() => _joining = true);
    try {
      await FirebaseFirestore.instance.collection('waitlist_regiao').add({
        'uf': _c.tutorUf,
        'cidade': _c.tutorCity,
        'contato': contact,
        'origem': 'app_tutor',
        'createdAt': FieldValue.serverTimestamp(),
      });
      Get.find<AnalyticsService>().logRegionAction('waitlist', _c.tutorUf, _c.tutorCity);
      if (mounted) setState(() => _joined = true);
    } catch (_) {
      Get.snackbar('Não foi possível enviar', 'Tente novamente em instantes.',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _openWhatsapp() async {
    final city = _hasRegion ? '${_c.tutorCity}/${_c.tutorUf}' : 'minha região';
    final text = 'Olá! Sou do app VetVem e não encontrei veterinários em $city. '
        'Preciso de: ';
    Get.find<AnalyticsService>()
        .logRegionAction('whatsapp', _c.tutorUf, _c.tutorCity);
    await launchUrl(
      Uri.parse('https://wa.me/$_whatsapp?text=${Uri.encodeComponent(text)}'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Busca vazia por texto/especialidade: mensagem simples.
    if (!widget.filterActive || !_hasRegion) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VvIcon(VvFn.emptySearch, size: 64, color: AppColors.textLight),
              SizedBox(height: 16),
              Text('Nenhum profissional encontrado',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMedium)),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Get.find<AnalyticsService>().logRegionAction('see_other_cities', _c.tutorUf, _c.tutorCity);
                _c.showAllCities();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.18),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset('assets/images/icone_proximos.png', width: 22, height: 22),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: Text(
                      'Ver veterinários próximos da sua região',
                      textAlign: TextAlign.center,
                      style: TextStyle(height: 1.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          const VvIcon(VvFn.emptyRegion, size: 56, color: AppColors.textLight),
          const SizedBox(height: 14),
          const Text(
            'Estamos chegando em novas regiões.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: _joined
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Pronto! Avisaremos você quando chegarmos aí.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF166534), fontSize: 13)),
                  )
                : ElevatedButton(
                    onPressed: _joining ? null : _join,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.18),
                    ),
                    child: Text(_joining ? 'Enviando…' : 'Avise-me quando chegar'),
                  ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openWhatsapp,
              icon: const VvIcon(VvFn.chat, size: 18, color: Vv2.primary),
              label: const Text('Falar com o VetVem no WhatsApp'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                backgroundColor: Colors.white,
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.18),
              ),
            ),
          ),
        ],
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
        color: Vv2.pressedSurface,
        shape: BoxShape.circle,
        image: image != null
            ? DecorationImage(image: image, fit: BoxFit.cover)
            : null,
      ),
      child: image == null
          ? Center(
              child: VvIcon(VvFn.userFallback,
                  color: Vv2.onBrand, size: size * 0.55))
          : null,
    );
  }
}
