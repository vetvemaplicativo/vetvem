import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../routes/app_routes.dart';
import '../../theme/vv2/vv_icons.dart';
import '../../theme/vv2/vv2_tokens.dart';
import '../profile/profile_controller.dart';
import 'claim_portal_sheet.dart';
import 'consulta_status.dart';

class ConsultasView extends StatelessWidget {
  const ConsultasView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ProfileController>();
    return Scaffold(
      backgroundColor: Vv2Pastel.cream,
      body: Column(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(gradient: Vv2.headerGradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Vv2.gutter, 20, Vv2.gutter, 22),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text('Minhas Consultas',
                              style: Vv2.t(28, 34, 700)),
                        ),
                        const SizedBox(height: 4),
                        Text('Acompanhe seus agendamentos',
                            style: Vv2.t(15, 20, 500, color: Vv2.onBrand)),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _FilterChips(ctrl: c),
          const SizedBox(height: 6),
          Expanded(
            child: Obx(() {
              final all = c.filteredConsultations;
              if (all.isEmpty) return const _EmptyState();
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(Vv2.gutter, 8, Vv2.gutter, 24),
                itemCount: all.length + 1,
                itemBuilder: (context, i) => i == all.length
                    ? const ClaimPortalCard()
                    : _ConsultaCard(item: all[i]),
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
      final selected = ctrl.consultaFilter.value;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Vv2.gutter),
        child: Row(
          children: [
            for (var i = 0; i < _filters.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Semantics(
                button: true,
                selected: selected == i,
                label: 'Filtro ${_filters[i]}',
                excludeSemantics: true,
                child: Material(
                  color: selected == i ? Vv2.primary : Vv2.surface,
                  shape: StadiumBorder(
                    side: BorderSide(
                        color: selected == i
                            ? Vv2.primary
                            : const Color(0xFFE8D5CA)),
                  ),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => ctrl.consultaFilter.value = i,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: Vv2.tapMin),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      alignment: Alignment.center,
                      child: Text(
                        _filters[i],
                        style: Vv2.t(15, 20, selected == i ? 700 : 600,
                            color: selected == i ? Vv2.onPrimary : Vv2.text),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

// ─── Consulta Card ────────────────────────────────────────────────────────────

class _ConsultaCard extends StatelessWidget {
  final ConsultationHistory item;
  const _ConsultaCard({required this.item});

  // O cancelamento pelo tutor é tratado pelo suporte (Termos 3.6): o botão
  // explica a regra e abre o e-mail já preenchido com os dados da consulta.
  void _showCancelInfo() {
    Get.dialog(
      AlertDialog(
        title: const Text('Cancelar consulta'),
        content: const Text(
          'Para cancelar, fale com o nosso suporte. Cancelamentos depois do '
          'pagamento são analisados caso a caso. Se o profissional recusar, '
          'não responder ou não comparecer, o valor é devolvido.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Voltar')),
          TextButton(
            onPressed: () async {
              Get.back();
              final quando = item.time.isNotEmpty ? '${item.date} às ${item.time}' : item.date;
              final assunto = Uri.encodeComponent('Cancelamento de consulta');
              final corpo = Uri.encodeComponent(
                'Olá! Gostaria de cancelar a consulta com ${item.vetName}'
                '${item.serviceName.isNotEmpty ? ' (${item.serviceName})' : ''} '
                'marcada para $quando.\n\nCódigo da consulta: ${item.id}',
              );
              await launchUrl(
                Uri.parse('mailto:suporte@vetvem.com.br?subject=$assunto&body=$corpo'),
              );
            },
            child: const Text('Falar com o suporte'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = item.status == 'completed';
    final st = ConsultaStatus.of(item);
    final quando = item.time.isNotEmpty ? '${item.date} · ${item.time}' : item.date;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Vv2.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Get.toNamed(Routes.consultaDetail, arguments: item),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConsultaStatusPill(st),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConsultaPetAvatar(photo: item.petPhotoBase64, size: 52),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.petName.isNotEmpty ? item.petName : 'Pet',
                                  style: Vv2.t(18, 24, 700)),
                              const SizedBox(height: 2),
                              Text(item.vetName,
                                  style: Vv2.t(15, 20, 600,
                                      color: Vv2.onPrimaryContainer)),
                              if (item.serviceName.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(item.serviceName,
                                    style: Vv2.t(14, 20, 400,
                                        color: Vv2.textSecondary)),
                              ],
                              const SizedBox(height: 6),
                              Row(children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 15, color: Vv2.textSecondary),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(quando,
                                      style: Vv2.t(14, 20, 600,
                                          color: Vv2.textSecondary)),
                                ),
                              ]),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 14),
                          child: VvIcon(VvFn.forward,
                              size: 20, color: Vv2.outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (item.status == 'upcoming') ...[
                const Divider(height: 1, color: Vv2.divider),
                TextButton.icon(
                  onPressed: _showCancelInfo,
                  icon: const Icon(Icons.close, size: 18),
                  label: Text('Cancelar', style: Vv2.t(15, 20, 700, color: const Color(0xFF8C1D18))),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF8C1D18),
                      minimumSize: const Size.fromHeight(Vv2.tapMin)),
                ),
              ],
              if (item.canRate) ...[
                const Divider(height: 1, color: Vv2.divider),
                TextButton.icon(
                  onPressed: () => Get.toNamed(Routes.rating, arguments: {
                    'consultationId': item.id,
                    'vetName': item.vetName,
                    'petName': item.petName,
                    'date': item.date,
                    'specialty': item.specialty,
                  }),
                  icon: const Icon(Icons.star_outline_rounded, size: 20),
                  label: Text('Avaliar atendimento',
                      style: Vv2.t(15, 20, 700, color: Vv2.primary)),
                  style: TextButton.styleFrom(
                    foregroundColor: Vv2.primary,
                    minimumSize: const Size.fromHeight(Vv2.tapMin),
                  ),
                ),
              ],
              if (isCompleted && item.rating != null) ...[
                const Divider(height: 1, color: Vv2.divider),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      ...List.generate(5, (i) => Icon(
                            i < item.rating!
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: i < item.rating!
                                ? const Color(0xFFE0A100)
                                : const Color(0xFFD1D5DB),
                            size: 18,
                          )),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.comment ?? 'Avaliado',
                          style: Vv2.t(14, 20, 400, color: Vv2.textSecondary),
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
      ),
    );
  }
}

/// Foto do pet (base64) ou ícone de calendário num círculo creme.
class ConsultaPetAvatar extends StatelessWidget {
  final String photo;
  final double size;
  const ConsultaPetAvatar({super.key, required this.photo, this.size = 48});

  @override
  Widget build(BuildContext context) {
    ImageProvider? img;
    if (photo.isNotEmpty) {
      try {
        img = MemoryImage(base64Decode(
            photo.contains(',') ? photo.split(',').last : photo));
      } catch (_) {}
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Vv2.pressedSurface,
        shape: BoxShape.circle,
        image: img != null
            ? DecorationImage(image: img, fit: BoxFit.cover)
            : null,
      ),
      child: img == null
          ? Center(
              child: VvIcon(VvFn.navConsults,
                  size: size * 0.48, color: Vv2.onPrimaryContainer))
          : null,
    );
  }
}

// ─── Empty ────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
                color: Vv2.pressedSurface, shape: BoxShape.circle),
            child: const Center(
              child: VvIcon(VvFn.navConsults,
                  size: 40, color: Vv2.onPrimaryContainer),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Nenhuma consulta ainda',
            textAlign: TextAlign.center, style: Vv2.t(18, 24, 700)),
        const SizedBox(height: 8),
        Text('Busque um veterinário e agende\nsua primeira consulta',
            textAlign: TextAlign.center,
            style: Vv2.t(15, 22, 400, color: Vv2.textSecondary)),
        const SizedBox(height: 24),
        const ClaimPortalCard(),
      ],
    );
  }
}
