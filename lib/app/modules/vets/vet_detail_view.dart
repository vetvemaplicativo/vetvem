import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/vet_model.dart';
import '../../services/analytics_service.dart';
import '../../services/taxonomy_service.dart';
import '../../theme/vv2/vv_icons.dart';
import '../../theme/vv2/vv2_tokens.dart';
import '../../theme/vv2/status_bar_shield.dart';
import 'vets_controller.dart';

class VetDetailView extends StatefulWidget {
  const VetDetailView({super.key});

  @override
  State<VetDetailView> createState() => _VetDetailViewState();
}

// Só registra o evento de "ver perfil" e delega a tela ao conteúdo de sempre.
class _VetDetailViewState extends State<VetDetailView> {
  @override
  void initState() {
    super.initState();
    final id = Get.find<VetsController>().selectedVet.value?.id ?? '';
    if (id.isNotEmpty) Get.find<AnalyticsService>().logViewVetProfile(id);
  }

  @override
  Widget build(BuildContext context) => const _VetDetailBody();
}

const _kCardBorder = Color(0xFFEAD9CC);
const _kStar = Color(0xFFF5A524);

class _VetDetailBody extends GetView<VetsController> {
  const _VetDetailBody();

  @override
  Widget build(BuildContext context) {
    final vet = controller.selectedVet.value;
    if (vet == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Get.back());
      return const SizedBox();
    }
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    final stack = scale > 1.15 || vet.animalSpecies.isEmpty;

    return Scaffold(
      backgroundColor: Vv2Pastel.cream,
      body: StatusBarShield(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 56 + 32 + bottomInset + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, vet),
                  Padding(
                    padding: const EdgeInsets.all(Vv2.gutter),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (stack) ...[
                          _buildSpecialties(vet),
                          if (vet.animalSpecies.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildAnimalSpecies(vet),
                          ],
                        ] else
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: _buildSpecialties(vet)),
                                const SizedBox(width: 12),
                                Expanded(child: _buildAnimalSpecies(vet)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        _buildNeighborhoods(vet),
                        const SizedBox(height: 12),
                        _buildBio(vet),
                        const SizedBox(height: 12),
                        _buildSchedule(vet),
                        const SizedBox(height: 12),
                        _buildPriceRow(vet),
                        const SizedBox(height: 12),
                        _buildReviews(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildCta(vet, bottomInset),
            ),
          ],
        ),
      ),
    );
  }

  // ── Cabeçalho ────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, VetModel vet) {
    final photo = vet.photoBase64;
    final url = vet.imageUrl;
    ImageProvider? image;
    if (photo.isNotEmpty) {
      image = MemoryImage(base64Decode(photo.split(',').last));
    } else if (url.isNotEmpty) {
      image = NetworkImage(url);
    }
    return Stack(
      children: [
        const Positioned.fill(
          child: Column(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: Vv2.headerGradient),
                  child: SizedBox.expand(),
                ),
              ),
              SizedBox(height: 70),
            ],
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Vv2.gutter, 12, Vv2.gutter, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Voltar',
                      excludeSemantics: true,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Get.back(),
                        child: Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Vv2.surface,
                            shape: BoxShape.circle,
                          ),
                          child: const VvIcon(
                            VvFn.back,
                            size: 24,
                            color: Vv2.onBrand,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Perfil do profissional',
                        style: Vv2.t(22, 28, 700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Vv2.surface.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Vv2.pressedSurface,
                      shape: BoxShape.circle,
                      image: image != null
                          ? DecorationImage(image: image, fit: BoxFit.cover)
                          : null,
                    ),
                    child: image == null
                        ? const Center(
                            child: VvIcon(
                              VvFn.userFallback,
                              size: 44,
                              color: Vv2.onBrand,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Vv2.gutter),
                  decoration: BoxDecoration(
                    color: Vv2.surface,
                    borderRadius: BorderRadius.circular(Vv2.rOverlay + 8),
                    boxShadow: Vv2.cardShadow,
                  ),
                  child: Column(
                    children: [
                      Text(
                        vet.name,
                        textAlign: TextAlign.center,
                        style: Vv2.t(26, 32, 700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${vet.crmv} · ${vet.specialty}',
                        textAlign: TextAlign.center,
                        style: Vv2.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      // Avaliação — calculada em tempo real das reviews carregadas
                      Obx(() {
                        final reviews = controller.vetReviews;
                        final count = reviews.length;
                        final avg = count > 0
                            ? reviews
                                      .map((r) => (r['rating'] as int))
                                      .reduce((a, b) => a + b) /
                                  count
                            : 0.0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBC2),
                            borderRadius: BorderRadius.circular(Vv2.rPill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const VvIcon(
                                VvFn.ratingFilled,
                                size: 20,
                                color: _kStar,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  count == 0
                                      ? 'Sem avaliações'
                                      : '${avg.toStringAsFixed(1)} ($count ${count == 1 ? 'avaliação' : 'avaliações'})',
                                  style: Vv2.t(15, 20, 700),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Blocos ───────────────────────────────────────────────────────

  Widget _chip(String text, {Color? bg, Color? fg}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: bg ?? Vv2.surface,
      borderRadius: BorderRadius.circular(Vv2.rPill),
    ),
    child: Text(text, style: Vv2.t(14, 20, 600, color: fg ?? Vv2.text)),
  );

  Widget _buildSpecialties(VetModel vet) {
    return _Section(
      title: 'Especialidades',
      color: const Color(0xFFFFD9C7),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: vet.specialtyTags.map((tag) => _chip(tag)).toList(),
      ),
    );
  }

  Widget _buildAnimalSpecies(VetModel vet) {
    // Lista completa recebida do app (TaxonomyService, config/species).
    final defs = {
      for (final sp in Get.find<TaxonomyService>().species) sp.key: sp.label,
    };
    return _Section(
      title: 'Espécies atendidas',
      color: const Color(0xFFE3EBDD),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: vet.animalSpecies.map((key) {
          final label = defs[key] ?? key;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Vv2.surface,
              borderRadius: BorderRadius.circular(Vv2.rControl + 8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                VvIcon.species(key, label, size: 24, color: Vv2.speciesGreen),
                const SizedBox(width: 6),
                Flexible(child: Text(label, style: Vv2.t(14, 20, 600))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNeighborhoods(VetModel vet) {
    return _Section(
      title: 'Regiões atendidas',
      outlined: true,
      child: Text(
        vet.neighborhoods.join(' · '),
        style: Vv2.bodyLarge.copyWith(color: Vv2.textSecondary),
      ),
    );
  }

  Widget _buildBio(VetModel vet) {
    return _Section(
      title: 'Sobre',
      outlined: true,
      child: Text(
        vet.bio,
        style: Vv2.bodyLarge.copyWith(color: Vv2.textSecondary),
      ),
    );
  }

  // ── Períodos de atendimento ──────────────────────────────────────

  static const _periodDefs = [
    (
      label: 'Manhã',
      icon: VvFn.periodMorning,
      hours: '08h–12h',
      min: 0,
      max: 11,
    ),
    (
      label: 'Tarde',
      icon: VvFn.periodAfternoon,
      hours: '12h–18h',
      min: 12,
      max: 17,
    ),
    (
      label: 'Noite',
      icon: VvFn.periodNight,
      hours: '18h–21h',
      min: 18,
      max: 23,
    ),
  ];

  Widget _buildSchedule(VetModel vet) {
    final activePeriods = _periodDefs.where((p) {
      return vet.availableTimes.any((t) {
        final h = int.tryParse(t.split(':').first) ?? -1;
        return h >= p.min && h <= p.max;
      });
    }).toList();

    return _Section(
      title: 'Períodos de atendimento',
      outlined: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: activePeriods
                .map(
                  (p) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Vv2.primaryContainer,
                      borderRadius: BorderRadius.circular(Vv2.rControl),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VvIcon(p.icon, size: 20, color: Vv2.onPrimaryContainer),
                        const SizedBox(width: 8),
                        Text(
                          '${p.label} · ${p.hours}',
                          style: Vv2.t(
                            14,
                            20,
                            600,
                            color: Vv2.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: vet.availableDays
                .map((d) => _chip(d, bg: const Color(0xFFF1F3F5)))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── Preço + disponibilidade ──────────────────────────────────────

  Widget _buildPriceRow(VetModel vet) {
    return Container(
      padding: const EdgeInsets.all(Vv2.gutter),
      decoration: _outlinedDecoration,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vet.hasMultipleServices
                      ? 'Consultas a partir de'
                      : 'Valor da consulta',
                  style: Vv2.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'R\$ ${vet.startingPrice.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: Vv2.t(26, 32, 700, color: Vv2.primary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: vet.isAvailable ? Vv2.successBg : const Color(0xFFE9ECF0),
              borderRadius: BorderRadius.circular(Vv2.rPill),
            ),
            child: Text(
              vet.isAvailable ? 'Hoje disponível' : 'Indisponível',
              style: Vv2.t(
                13,
                18,
                700,
                color: vet.isAvailable ? Vv2.successFg : Vv2.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviews() {
    return Obx(() {
      final loading = controller.isLoadingReviews.value;
      final reviews = controller.vetReviews;

      return _Section(
        title: 'Avaliações (${reviews.length})',
        outlined: true,
        child: loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            : reviews.isEmpty
            ? Text('Nenhuma avaliação ainda.', style: Vv2.bodyMedium)
            : Column(
                children: reviews
                    .take(5)
                    .map((r) => _ReviewCard(review: r))
                    .toList(),
              ),
      );
    });
  }

  // ── CTA fixo ─────────────────────────────────────────────────────

  Widget _buildCta(VetModel vet, double bottomInset) {
    final enabled = vet.isAvailable;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Vv2Pastel.cream.withValues(alpha: 0), Vv2Pastel.cream],
          stops: const [0, 0.35],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Vv2.gutter,
          16,
          Vv2.gutter,
          12 + bottomInset,
        ),
        child: Semantics(
          button: true,
          enabled: enabled,
          label: enabled ? 'Agendar consulta' : 'Veterinário indisponível',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: enabled ? () => controller.scheduleVet(vet) : null,
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.fromLTRB(24, 6, 6, 6),
              decoration: BoxDecoration(
                gradient: enabled ? Vv2.ctaGradient : null,
                color: enabled ? null : const Color(0xFFE9ECF0),
                borderRadius: BorderRadius.circular(Vv2.rPill),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      enabled ? 'Agendar consulta' : 'Veterinário indisponível',
                      textAlign: TextAlign.center,
                      style: Vv2.t(
                        17,
                        24,
                        700,
                        color: enabled ? Vv2.onBrand : Vv2.textSecondary,
                      ),
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Vv2.surface.withValues(alpha: enabled ? 0.7 : 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: VvIcon(
                      VvFn.forward,
                      size: 20,
                      color: enabled ? Vv2.onBrand : Vv2.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final _outlinedDecoration = BoxDecoration(
  color: Vv2.surface,
  borderRadius: BorderRadius.circular(Vv2.rOverlay),
  border: Border.all(color: _kCardBorder),
);

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final rating = review['rating'] as int;
    final comment = review['comment'] as String;
    final tutorName = review['tutorName'] as String;
    final petName = review['petName'] as String;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Vv2.pressedSurface,
                child: Text(
                  tutorName.isNotEmpty ? tutorName[0].toUpperCase() : '?',
                  style: Vv2.t(15, 20, 700, color: Vv2.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tutorName, style: Vv2.t(15, 20, 700)),
                    if (petName.isNotEmpty)
                      Text('Pet: $petName', style: Vv2.bodySmall),
                  ],
                ),
              ),
              Semantics(
                label: 'Nota $rating de 5',
                excludeSemantics: true,
                child: Row(
                  children: List.generate(
                    5,
                    (i) => VvIcon(
                      i < rating ? VvFn.ratingFilled : VvFn.ratingEmpty,
                      size: 16,
                      color: _kStar,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 48),
              child: Text(
                '"$comment"',
                style: Vv2.bodyMedium.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Vv2.text,
                ),
              ),
            ),
          const Divider(height: 20, color: Vv2.divider),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Color? color;
  final bool outlined;

  const _Section({
    required this.title,
    required this.child,
    this.color,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Vv2.gutter),
      decoration: outlined
          ? _outlinedDecoration
          : BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(Vv2.rOverlay),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Vv2.t(18, 24, 700)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
