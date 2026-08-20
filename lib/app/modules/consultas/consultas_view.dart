import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../profile/profile_controller.dart';

class ConsultasView extends StatelessWidget {
  const ConsultasView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ProfileController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Material(
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Minhas Consultas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Acompanhe seus agendamentos',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Filter chips
                    _FilterChips(ctrl: c),
                  ],
                ),
              ),
            ),
          ),

          // Lista
          Expanded(
            child: Obx(() {
              final all = c.filteredConsultations;
              if (all.isEmpty) return const _EmptyState();
              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: all.length,
                itemBuilder: (context, i) => _ConsultaCard(item: all[i]),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── Filter chips ─────────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final ProfileController ctrl;
  const _FilterChips({required this.ctrl});

  static const _filters = ['Todas', 'Agendadas', 'Concluídas', 'Canceladas'];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = ctrl.consultaFilter.value; // leitura síncrona — GetX rastreia aqui
      return SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final sel = selected == i;
              return GestureDetector(
                onTap: () => ctrl.consultaFilter.value = i,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: sel
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      _filters[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? AppColors.primary : Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
    });
  }
}

// ─── Consulta Card ────────────────────────────────────────────────────────────

class _ConsultaCard extends StatelessWidget {
  final ConsultationHistory item;
  const _ConsultaCard({required this.item});

  Widget _buildPetAvatar(String photo) {
    ImageProvider? img;
    if (photo.isNotEmpty) {
      try {
        img = MemoryImage(base64Decode(
            photo.contains(',') ? photo.split(',').last : photo));
      } catch (_) {}
    }
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
        image: img != null
            ? DecorationImage(image: img, fit: BoxFit.cover)
            : null,
      ),
      child: img == null
          ? const Icon(Icons.pets, color: AppColors.primary, size: 26)
          : null,
    );
  }

  Color get _statusColor {
    switch (item.status) {
      case 'completed': return AppColors.success;
      case 'cancelled': return AppColors.error;
      case 'rejected': return AppColors.error;
      case 'confirmed': return AppColors.success;
      case 'pending_confirmation': return AppColors.warning;
      default: return AppColors.warning;
    }
  }

  String get _statusLabel {
    switch (item.status) {
      case 'completed': return 'Concluída';
      case 'cancelled': return 'Cancelada';
      case 'rejected': return 'Recusada';
      case 'confirmed': return 'Confirmada ✓';
      case 'pending_confirmation': return 'Aguard. confirmação';
      case 'pending_payment': return 'Aguard. pagamento';
      default: return 'Agendada';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = item.status == 'completed';
    final isCancelled = item.status == 'cancelled' || item.status == 'rejected';
    final statusColor = _statusColor;
    final statusLabel = _statusLabel;

    return GestureDetector(
      onTap: () => Get.toNamed(Routes.consultaDetail, arguments: item),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          // Topo com status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.07),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(
                  isCompleted
                      ? Icons.check_circle_outline
                      : isCancelled
                          ? Icons.cancel_outlined
                          : Icons.schedule,
                  color: statusColor,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          // Conteúdo
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar do pet
                _buildPetAvatar(item.petPhotoBase64),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pet em destaque
                      Row(
                        children: [
                          const Text('🐾', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              item.petName.isNotEmpty
                                  ? item.petName
                                  : 'Pet',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppColors.textDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Profissional
                      Text(
                        item.vetName,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary),
                      ),
                      const SizedBox(height: 3),
                      // Procedimento
                      if (item.serviceName.isNotEmpty)
                        Text(
                          item.serviceName,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMedium),
                        ),
                      const SizedBox(height: 6),
                      // Data + hora
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 13, color: AppColors.textLight),
                          const SizedBox(width: 4),
                          Text(
                            item.time.isNotEmpty
                                ? '${item.date}  ·  ${item.time}'
                                : item.date,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMedium),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Ações
          if (item.status == 'upcoming') ...[
            const Divider(height: 1),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Cancelar'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.error),
                  ),
                ),
                Container(width: 1, height: 40, color: const Color(0xFFE5E7EB)),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: const Text('Contato'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary),
                  ),
                ),
              ],
            ),
          ],
          // Botão avaliar — concluídas sem avaliação
          if (item.canRate) ...[
            const Divider(height: 1),
            TextButton.icon(
              onPressed: () => Get.toNamed(Routes.rating, arguments: {
                'consultationId': item.id,
                'vetName': item.vetName,
                'petName': item.petName,
                'date': item.date,
                'specialty': item.specialty,
              }),
              icon: const Icon(Icons.star_outline_rounded, size: 18),
              label: const Text('Avaliar atendimento'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFBBC05),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
          // Rating already given
          if (isCompleted && item.rating != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  ...List.generate(5, (i) => Icon(
                        i < item.rating!
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: i < item.rating!
                            ? const Color(0xFFFBBC05)
                            : const Color(0xFFD1D5DB),
                        size: 16,
                      )),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.comment ?? 'Avaliado',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMedium),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}

// ─── Empty ────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 64, color: AppColors.textLight.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text(
            'Nenhuma consulta ainda',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium),
          ),
          const SizedBox(height: 8),
          const Text(
            'Busque um veterinário e agende\nsua primeira consulta',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}
