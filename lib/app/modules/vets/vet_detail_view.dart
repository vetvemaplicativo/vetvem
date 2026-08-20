import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../theme/app_theme.dart';
import '../../data/models/vet_model.dart';
import '../../services/taxonomy_service.dart';
import 'vets_controller.dart';

class VetDetailView extends GetView<VetsController> {
  const VetDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final vet = controller.selectedVet.value;
    if (vet == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Get.back());
      return const SizedBox();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(vet),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildSpecialties(context, vet),
                  if (vet.animalSpecies.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildAnimalSpecies(context, vet),
                  ],
                  const SizedBox(height: 20),
                  _buildNeighborhoods(context, vet),
                  const SizedBox(height: 20),
                  _buildBio(context, vet),
                  const SizedBox(height: 20),
                  _buildSchedule(context, vet),
                  const SizedBox(height: 20),
                  _buildPriceRow(vet),
                  const SizedBox(height: 20),
                  _buildReviews(),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: vet.isAvailable
                        ? () => controller.scheduleVet(vet)
                        : null,
                    child: Text(vet.isAvailable
                        ? 'Agendar consulta'
                        : 'Veterinário indisponível'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header laranja ───────────────────────────────────────────────

  Widget _buildHeader(VetModel vet) {
    return Material(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // AppBar row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 20),
                    onPressed: () => Get.back(),
                  ),
                  const Expanded(
                    child: Text(
                      'Perfil do profissional',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Avatar
            () {
              final photo = vet.photoBase64;
              final url = vet.imageUrl;
              ImageProvider? image;
              if (photo.isNotEmpty) {
                image = MemoryImage(base64Decode(photo.split(',').last));
              } else if (url.isNotEmpty) {
                image = NetworkImage(url);
              }
              return Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  image: image != null
                      ? DecorationImage(image: image, fit: BoxFit.cover)
                      : null,
                ),
                child: image == null
                    ? const Icon(Icons.person, color: Colors.white, size: 42)
                    : null,
              );
            }(),
            const SizedBox(height: 12),
            Text(
              vet.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${vet.crmv} · ${vet.specialty}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 8),
            // Avaliação — calculada em tempo real das reviews carregadas
            Obx(() {
              final reviews = controller.vetReviews;
              final count = reviews.length;
              final avg = count > 0
                  ? reviews.map((r) => (r['rating'] as int)).reduce((a, b) => a + b) / count
                  : 0.0;
              final floor = avg.floor();
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...List.generate(5, (i) => Icon(
                        i < floor
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 18,
                      )),
                  const SizedBox(width: 6),
                  Text(
                    count == 0
                        ? 'Sem avaliações'
                        : '${avg.toStringAsFixed(1)} ($count ${count == 1 ? 'avaliação' : 'avaliações'})',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Especialidades ───────────────────────────────────────────────

  Widget _buildSpecialties(BuildContext context, VetModel vet) {
    return _Section(
      title: 'Especialidades',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: vet.specialtyTags.map((tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tag,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Poppins',
                ),
              ),
            )).toList(),
      ),
    );
  }

  // ── Espécies atendidas ───────────────────────────────────────────

  Widget _buildAnimalSpecies(BuildContext context, VetModel vet) {
    // Vem do TaxonomyService (config/species no Firestore).
    final speciesLabels = {
      for (final sp in Get.find<TaxonomyService>().species)
        sp.key: '${sp.emoji} ${sp.label}',
    };
    return _Section(
      title: 'Espécies atendidas',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: vet.animalSpecies.map((s) {
          final label = speciesLabels[s] ?? s;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF16A34A),
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Regiões atendidas ────────────────────────────────────────────

  Widget _buildNeighborhoods(BuildContext context, VetModel vet) {
    return _Section(
      title: 'Regiões atendidas',
      child: Text(
        vet.neighborhoods.join(' · '),
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textMedium,
          fontFamily: 'Poppins',
          height: 1.5,
        ),
      ),
    );
  }

  // ── Bio ──────────────────────────────────────────────────────────

  Widget _buildBio(BuildContext context, VetModel vet) {
    return _Section(
      title: 'Sobre',
      child: Text(
        vet.bio,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textMedium,
          fontFamily: 'Poppins',
          height: 1.6,
        ),
      ),
    );
  }

  // ── Períodos de atendimento ──────────────────────────────────────

  static const _periodDefs = [
    (label: 'Manhã',  icon: Icons.wb_sunny_outlined,   hours: '08h–12h', min: 0,  max: 11),
    (label: 'Tarde',  icon: Icons.wb_cloudy_outlined,  hours: '12h–18h', min: 12, max: 17),
    (label: 'Noite',  icon: Icons.nights_stay_outlined, hours: '18h–21h', min: 18, max: 23),
  ];

  Widget _buildSchedule(BuildContext context, VetModel vet) {
    final activePeriods = _periodDefs.where((p) {
      return vet.availableTimes.any((t) {
        final h = int.tryParse(t.split(':').first) ?? -1;
        return h >= p.min && h <= p.max;
      });
    }).toList();

    return _Section(
      title: 'Períodos de atendimento',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: activePeriods.indexed.map(((int, ({String label, IconData icon, String hours, int min, int max})) e) {
              final (i, p) = e;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < activePeriods.length - 1 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Icon(p.icon, size: 20, color: AppColors.primary),
                      const SizedBox(height: 4),
                      Text(p.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12,
                            color: AppColors.primary, fontFamily: 'Poppins',
                          )),
                      Text(p.hours,
                          style: const TextStyle(
                            fontSize: 10, color: AppColors.textMedium,
                            fontFamily: 'Poppins',
                          )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: vet.availableDays.map((d) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(d,
                  style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500,
                    color: AppColors.textMedium, fontFamily: 'Poppins',
                  )),
            )).toList(),
          ),
        ],
      ),
    );
  }

  // ── Preço + disponibilidade ──────────────────────────────────────

  Widget _buildPriceRow(VetModel vet) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vet.hasMultipleServices ? 'Consultas a partir de' : 'Valor da consulta',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMedium,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'R\$ ${vet.startingPrice.toStringAsFixed(2).replaceAll('.', ',')}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: vet.isAvailable
                  ? AppColors.success.withValues(alpha: 0.12)
                  : AppColors.textLight.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              vet.isAvailable ? 'Hoje disponível' : 'Indisponível',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: vet.isAvailable ? AppColors.success : AppColors.textLight,
                fontFamily: 'Poppins',
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
        child: loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ))
            : reviews.isEmpty
                ? const Text(
                    'Nenhuma avaliação ainda.',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                        fontFamily: 'Poppins'),
                  )
                : Column(
                    children: reviews
                        .take(5)
                        .map((r) => _ReviewCard(review: r))
                        .toList(),
                  ),
      );
    });
  }
}

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
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  tutorName.isNotEmpty ? tutorName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tutorName,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                            fontFamily: 'Poppins')),
                    if (petName.isNotEmpty)
                      Text('Pet: $petName',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textLight,
                              fontFamily: 'Poppins')),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 14,
                    color: Colors.amber,
                  ),
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 40),
              child: Text(
                '"$comment"',
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMedium,
                    fontFamily: 'Poppins',
                    fontStyle: FontStyle.italic,
                    height: 1.4),
              ),
            ),
          const Divider(height: 16),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
