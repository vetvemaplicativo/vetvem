import '../home/region_picker_sheet.dart';
import 'dart:convert';
import '../../services/analytics_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../theme/vv2/vv_icons.dart';
import '../../theme/vv2/vv2_tokens.dart';
import '../../data/models/vet_model.dart';
import '../../widgets/shimmer.dart';
import '../../widgets/auth_widgets.dart';
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
              style: Vv2.bodyLarge.copyWith(decoration: TextDecoration.none),
              child: Obx(() {
                final estado = controller.estado.value;
                final vets = controller.filteredVets.toList();
                final nearby = controller.showOtherCities.value;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Vv2.gutter, 16, Vv2.gutter, 32),
                  children: [
                    _RegionRow(c: controller),
                    const SizedBox(height: 20),
                    ...switch (estado) {
                      BuscaEstado.carregando => _loading(controller),
                      BuscaEstado.semRegiao => [_ChooseRegion(c: controller)],
                      BuscaEstado.resultados =>
                        _results(context, controller, vets, nearby),
                      _ => [_EmptyState(key: ValueKey(estado), estado: estado)],
                    },
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _loading(VetsController c) => [
        Semantics(
          liveRegion: true,
          child: Text('Buscando profissionais…', style: Vv2.headlineSmall),
        ),
        if (c.hasRegion) ...[
          const SizedBox(height: 4),
          Text('Resultados para ${c.regionLabel}', style: Vv2.bodyMedium),
        ],
        const SizedBox(height: 16),
        const ExcludeSemantics(
          child: Column(children: [
            VetCardSkeleton(),
            SizedBox(height: 14),
            VetCardSkeleton(),
          ]),
        ),
      ];

  List<Widget> _results(BuildContext context, VetsController c,
      List<VetModel> vets, bool nearby) {
    final n = vets.length;
    final qtd = '$n ${n == 1 ? 'profissional' : 'profissionais'}';
    final titulo = nearby
        ? 'Perto de você'
        : (c.bairroMode ? 'No seu bairro' : 'Na sua cidade');
    final sub = nearby
        ? '$qtd a até ${VetsController.nearbyRadiusKm.round()} km de ${c.regionLabel}'
        : '$qtd em ${c.bairroMode ? c.tutorBairro : c.tutorCity}';
    return [
      Row(
        children: [
          Expanded(child: Text(titulo, style: Vv2.headlineSmall)),
          GetBuilder<VetsController>(
            builder: (c) => Semantics(
              button: true,
              label: 'Ordenar por: ${_sortLabel(c.sortIndex.value)}',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(Vv2.rControl),
                onTap: () => _showSortSheet(context, c),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: Vv2.tapMin),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Center(
                      widthFactor: 1,
                      child: Text(_sortLabel(c.sortIndex.value),
                          style: Vv2.t(14, 20, 700, color: Vv2.primary)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      Text(sub, style: Vv2.bodyMedium),
      const SizedBox(height: 16),
      ...vets.map((v) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: VetCard(vet: v),
          )),
      if (!nearby) ...[
        const SizedBox(height: 6),
        VvPillButton(
          label: 'Ampliar para ${VetsController.nearbyRadiusKm.round()} km',
          kind: VvPillKind.outlined,
          onTap: () => _ampliar(c),
        ),
      ],
    ];
  }
}

void _ampliar(VetsController c) {
  Get.find<AnalyticsService>()
      .logRegionAction('see_other_cities', c.tutorUf, c.tutorCity);
  c.showAllCities();
}

/// Região de referência sempre visível + pílula do raio quando ativo.
class _RegionRow extends StatelessWidget {
  final VetsController c;
  const _RegionRow({required this.c});

  @override
  Widget build(BuildContext context) {
    final nearby = c.showOtherCities.value;
    // Seletor Estado → Cidade para visitante e conta sem endereço; com
    // endereço, a pílula alterna entre o bairro e a cidade toda.
    final seletor = !c.fromAddress;
    final label = !c.hasRegion
        ? 'Escolher região'
        : (c.bairroMode
            ? '${c.tutorBairro}, ${c.regionLabel}'
            : c.regionLabel);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _AreaPill(
          active: true,
          label: label,
          chevron: seletor,
          onTap: () =>
              seletor ? RegionPickerSheet.show() : c.toggleAreaFilter(),
        ),
        if (nearby)
          _RadiusPill(
            label: 'Até ${VetsController.nearbyRadiusKm.round()} km',
            onTap: c.toggleAreaFilter,
          ),
      ],
    );
  }
}

class _RadiusPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _RadiusPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: true,
      label: '$label. Toque para voltar à sua cidade',
      excludeSemantics: true,
      child: Material(
        color: Vv2.surface,
        shape: const StadiumBorder(side: BorderSide(color: Vv2.divider)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: Vv2.tapMin),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: Vv2.t(14, 20, 700)),
                const SizedBox(width: 8),
                const Icon(Icons.close_rounded, size: 18, color: Vv2.onBrand),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AreaPill extends StatelessWidget {
  final bool active;
  final String label;
  final bool chevron;
  final VoidCallback onTap;
  const _AreaPill(
      {required this.active,
      required this.label,
      required this.onTap,
      this.chevron = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: chevron ? 'Região: $label. Toque para trocar' : 'Região: $label',
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
                if (chevron) ...[
                  const SizedBox(width: 6),
                  const VvIcon(VvFn.expand, size: 16, color: Vv2.onBrand),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Visitante (ou conta sem endereço) sem cidade: Estado → Cidade, usando o
/// seletor existente (cidades atendidas + "Minha cidade não aparece").
class _ChooseRegion extends StatelessWidget {
  final VetsController c;
  const _ChooseRegion({required this.c});

  @override
  Widget build(BuildContext context) {
    Widget field(String label, String hint) => Semantics(
          button: true,
          label: '$label: $hint',
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(Vv2.rControl),
            onTap: RegionPickerSheet.show,
            child: Container(
              constraints: const BoxConstraints(minHeight: Vv2.fieldMin),
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
              decoration: BoxDecoration(
                color: Vv2.surface,
                borderRadius: BorderRadius.circular(Vv2.rControl),
                border: Border.all(color: Vv2.outline),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label,
                          style: Vv2.t(12, 16, 600, color: Vv2.textSecondary)),
                      Text(hint, style: Vv2.titleMedium),
                    ],
                  ),
                ),
                const VvIcon(VvFn.expand, size: 20, color: Vv2.onBrand),
              ]),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Onde você quer atendimento?', style: Vv2.headlineSmall),
        const SizedBox(height: 8),
        Text(
            'Escolha o estado e depois a cidade para ver quem atende na sua região.',
            style: Vv2.t(15, 22, 400, color: Vv2.textSecondary)),
        const SizedBox(height: 24),
        field('Estado', 'Selecione o estado'),
        const SizedBox(height: 12),
        field('Cidade', 'Selecione a cidade'),
        const SizedBox(height: 20),
        VvPillButton(label: 'Ver profissionais', onTap: RegionPickerSheet.show),
      ],
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
                Vv2.gutter, 12, Vv2.gutter, 8),
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
                                  ? 'Buscar profissionais'
                                  : c.selectedSpecialty.value,
                              style: Vv2.t(26, 32, 700),
                            ),
                            Text(
                                c.selectedSpecialty.value.isEmpty
                                    ? 'Serviços veterinários'
                                    : 'Profissionais por serviço',
                                style: Vv2.bodyMedium
                                    .copyWith(color: Vv2.onBrand)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Busca centralizada entre o subtítulo e os chips (ajuste do
                // Ronald): 16 acima; abaixo 8 + 8 de folga interna dos chips.
                const SizedBox(height: 16),
                TextField(
                  controller: c.searchController,
                  style: Vv2.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Nome ou especialidade',
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
                const SizedBox(height: 8),
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
    final etiqueta = controller.nearbyLabel(vet);
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () => controller.openVetDetail(vet),
        child: Opacity(
          opacity: vet.isAvailable ? 1.0 : 0.55,
          child: Container(
            // Mais respiro embaixo: a etiqueta não fica colada na borda.
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
            decoration: BoxDecoration(
              color: Vv2.surface,
              borderRadius: BorderRadius.circular(Vv2.rOverlay),
              border: Border.all(color: Vv2.pressedSurface),
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const VvIcon(VvFn.ratingBadge,
                            size: 14, color: Vv2.onBrand),
                        const SizedBox(width: 3),
                        Text(vet.rating.toStringAsFixed(1).replaceAll('.', ','),
                            style: Vv2.t(13, 18, 700)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 14),
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
                      const SizedBox(height: 2),
                      Text(vet.specialty,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Vv2.bodyMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          Text(
                              vet.hasMultipleServices
                                  ? 'A partir de $price'
                                  : price,
                              style: Vv2.t(18, 24, 700, color: Vv2.primary)),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                                vet.hasMultipleServices
                                    ? 'por serviço'
                                    : 'por visita',
                                style: Vv2.t(12, 16, 600,
                                    color: Vv2.textSecondary)),
                          ),
                        ],
                      ),
                      if (etiqueta != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Vv2.pressedSurface,
                            borderRadius: BorderRadius.circular(Vv2.rPill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const VvIcon(VvFn.location,
                                  size: 14, color: Vv2.onPrimaryContainer),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(etiqueta,
                                    style: Vv2.t(13, 18, 700,
                                        color: Vv2.onPrimaryContainer)),
                              ),
                            ],
                          ),
                        ),
                      ],
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

// ─── Estados vazios ───────────────────────────────────────────────────────────

class _EmptyState extends StatefulWidget {
  final BuscaEstado estado;
  const _EmptyState({super.key, required this.estado});

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
    // Só registra demanda quando está confirmado que não há cobertura em 50 km.
    if (_hasRegion && widget.estado == BuscaEstado.vazioRegiao) {
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
    if (user == null || contact.length < 5 || !_hasRegion) {
      // Visitante sem e-mail: o WhatsApp continua disponível.
      Get.snackbar('Entre na sua conta',
          'Precisamos do seu e-mail para avisar quando chegarmos aí.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
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
    final c = _c;
    final raio = VetsController.nearbyRadiusKm.round();
    final nearby = c.showOtherCities.value;
    final onde = nearby ? 'em até $raio km de ${c.tutorCity}' : 'em ${c.tutorCity}';
    final servico = c.selectedSpecialty.value;
    final texto = c.searchController.text.trim();

    late final VvFn icon;
    late final String titulo;
    late final String corpo;
    final acoes = <Widget>[];

    switch (widget.estado) {
      case BuscaEstado.vazioFiltro:
        icon = VvFn.emptySearch;
        titulo = servico.isNotEmpty
            ? 'Nenhum profissional de $servico $onde ainda'
            : 'Nenhum resultado para “$texto”';
        corpo = nearby
            ? 'Há profissionais de outros serviços perto de você.'
            : (c.bairroMode
                ? 'Há profissionais de outros serviços no seu bairro.'
                : 'Há profissionais de outros serviços na sua cidade.');
        acoes.add(VvPillButton(
            label: 'Ver todos os serviços', onTap: c.clearServiceFilter));
        if (!nearby) {
          acoes.add(VvPillButton(
              label: 'Ampliar para $raio km',
              kind: VvPillKind.outlined,
              onTap: () => _ampliar(c)));
        }
      case BuscaEstado.vazioCidade:
        icon = VvFn.emptyRegion;
        if (c.cidadeTemProfissional) {
          titulo = 'Nenhum profissional em ${c.tutorBairro} ainda';
          corpo = 'Há profissionais que atendem outros bairros de ${c.tutorCity}.';
          acoes.add(VvPillButton(
              label: 'Ver toda a cidade', onTap: c.toggleAreaFilter));
        } else {
          titulo = 'Nenhum profissional em ${c.tutorCity} ainda';
          corpo = 'Encontramos profissionais em até $raio km da sua cidade.';
          acoes.add(VvPillButton(
              label: 'Ampliar para $raio km', onTap: () => _ampliar(c)));
        }
      default: // vazioRegiao
        icon = VvFn.emptyRegion;
        titulo = 'Ainda não atendemos sua região';
        corpo = 'Não encontramos profissionais em até $raio km de ${c.tutorCity}.';
        acoes.add(_joined
            ? Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Vv2.successBg,
                  borderRadius: BorderRadius.circular(Vv2.rCard),
                ),
                child: Text('Pronto! Avisaremos você quando chegarmos aí.',
                    textAlign: TextAlign.center,
                    style: Vv2.t(14, 20, 600, color: Vv2.successFg)),
              )
            : VvPillButton(
                label: 'Avise-me quando chegar',
                loading: _joining,
                onTap: _joining ? null : _join));
        acoes.add(VvPillButton(
            label: 'Falar com o VetVem no WhatsApp',
            kind: VvPillKind.outlined,
            onTap: _openWhatsapp));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            decoration: BoxDecoration(
              color: Vv2.surface,
              borderRadius: BorderRadius.circular(Vv2.rOverlay),
              border: Border.all(color: Vv2.pressedSurface),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        color: Vv2.pressedSurface, shape: BoxShape.circle),
                    child: VvIcon(icon, size: 24, color: Vv2.onBrand),
                  ),
                ),
                const SizedBox(height: 16),
                Text(titulo, style: Vv2.t(20, 28, 700)),
                const SizedBox(height: 8),
                Text(corpo, style: Vv2.t(15, 22, 400, color: Vv2.textSecondary)),
              ],
            ),
          ),
        ),
        for (final a in acoes) ...[const SizedBox(height: 14), a],
      ],
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
