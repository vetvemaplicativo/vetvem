import 'dart:convert';
import '../consultas/proposal_card.dart';
import '../consultas/relocation_card.dart';
import 'first_consult_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../theme/app_theme.dart';
import '../../data/models/appointment_model.dart';
import '../vets/vets_view.dart';
import '../vets/vets_controller.dart';
import '../consultas/consultas_view.dart';
import '../profile/profile_view.dart';
import '../../services/taxonomy_service.dart';
import 'home_controller.dart';
import '../../widgets/guest_widgets.dart';
import '../../theme/vv2/vv2_tokens.dart';
import '../../theme/vv2/vv_icons.dart';
import 'home_nav_v2.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _HomeTab(),
      const Material(child: VetsView()),
      controller.isGuest
          ? const GuestGate(
              icon: Icons.receipt_long_outlined,
              title: 'Suas consultas ficam aqui',
              message:
                  'Crie sua conta ou entre para agendar e acompanhar suas consultas, '
                  'receber o prontuário e avaliar o atendimento.',
            )
          : const Material(child: ConsultasView()),
      controller.isGuest
          ? const GuestGate(
              icon: Icons.person_outline,
              title: 'Seu perfil e seus pets',
              message:
                  'Crie sua conta ou entre para cadastrar seus pets, endereços e '
                  'dados de contato.',
            )
          : const Material(child: ProfileView()),
    ];

    return Obx(() => AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: Scaffold(
            backgroundColor: Vv2Pastel.cream,
            body: IndexedStack(
              index: controller.currentIndex.value,
              children: pages,
            ),
            bottomNavigationBar: HomeNavV2(
              currentIndex: controller.currentIndex.value,
              onTap: controller.changeTab,
            ),
          ),
        ));
  }
}

// ─── Home Tab ────────────────────────────────────────────────────────────────

class _HomeTab extends GetView<HomeController> {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Orange header
          _buildHeader(context),
          // Body
          Padding(
            padding: const EdgeInsets.all(Vv2.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                if (!controller.isGuest) ...const [
                  RelocationBanner(),
                  ProposalsBanner(),
                  FirstConsultGuide(),
                ],
                _buildCategories(context),
                const SizedBox(height: 28),
                _buildUpcomingAppointment(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Cabeçalho (redesign 2.0) ─────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 360;
    final photoH = compact ? 112.0 : 136.0;
    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              const Expanded(
                  child: DecoratedBox(
                      decoration: BoxDecoration(gradient: Vv2.headerGradient),
                      child: SizedBox.expand())),
              SizedBox(height: photoH / 2),
            ],
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Vv2.gutter, 12, Vv2.gutter, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Semantics(
                      label: 'VetVem',
                      image: true,
                      child: Image.asset('assets/images/logo_light.png',
                          width: 48,
                          height: 48,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _locationPill(),
                      ),
                    ),
                    if (!controller.isGuest) ...[
                      const SizedBox(width: 8),
                      _bell(context),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Obx(() => Text(
                      controller.isGuest
                          ? 'Olá!'
                          : 'Olá, ${controller.userName.value}!',
                      style: Vv2.t(26, 31, 700),
                    )),
                const SizedBox(height: 4),
                Text('O que seu pet precisa hoje?', style: Vv2.t(22, 29, 700)),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(Vv2.rCard),
                  child: Image.asset('assets/images/tutor_home_hero_pets.webp',
                      width: double.infinity,
                      height: photoH,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _locationPill() {
    final guest = controller.isGuest;
    final pill = Container(
      constraints: const BoxConstraints(minHeight: Vv2.tapMin),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Vv2.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(Vv2.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const VvIcon(VvFn.location, size: 20, color: Vv2.onBrand),
          const SizedBox(width: 8),
          Flexible(
            child: Obx(() => Text(controller.locationLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Vv2.t(15, 20, 700))),
          ),
          if (guest) ...[
            const SizedBox(width: 8),
            const VvIcon(VvFn.expand, size: 16, color: Vv2.onBrand),
          ],
        ],
      ),
    );
    if (!guest) return pill;
    return Semantics(
      button: true,
      label: 'Escolher cidade',
      excludeSemantics: true,
      child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: controller.pickRegion,
          child: pill),
    );
  }

  Widget _bell(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Notificações',
      child: GestureDetector(
        onTap: () {
          controller.markNotificationsSeen();
          _showNotifications(context);
        },
        child: SizedBox(
          width: Vv2.tapMin,
          height: Vv2.tapMin,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Vv2.surface.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: const VvIcon(VvFn.notifications,
                    color: Vv2.onBrand, size: 22),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Obx(() => controller.unreadNotifications.value > 0
                    ? Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Vv2.brand,
                          shape: BoxShape.circle,
                        ),
                      )
                    : const SizedBox.shrink()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Notificações ─────────────────────────────────────────────────

  void _showNotifications(BuildContext context) {
    String ago(DateTime? t) {
      if (t == null) return '';
      final d = DateTime.now().difference(t);
      if (d.inMinutes < 1) return 'agora';
      if (d.inMinutes < 60) return 'há ${d.inMinutes} min';
      if (d.inHours < 24) return 'há ${d.inHours} h';
      if (d.inDays == 1) return 'ontem';
      return 'há ${d.inDays} dias';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scroll) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Notificações',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              const SizedBox(height: 12),
              Expanded(
                child: Obx(() {
                  final items = controller.notifications;
                  if (items.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Você ainda não tem notificações.\nQuando um veterinário responder ao seu pedido, você vê aqui.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppColors.textMedium),
                        ),
                      ),
                    );
                  }
                  return ListView(
                    controller: scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: items.map((n) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: AppColors.cardShadow,
                            blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const VvIcon(VvFn.notifications,
                                color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${n['title']}', style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13,
                                    color: AppColors.textDark)),
                                if ('${n['body']}'.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text('${n['body']}', style: const TextStyle(
                                      fontSize: 12, color: AppColors.textMedium)),
                                ],
                                const SizedBox(height: 4),
                                Text(ago(n['createdAt'] as DateTime?),
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.textLight)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Categorias ───────────────────────────────────────────────────
  // Especialidades vêm do TaxonomyService (config/specialties no Firestore,
  // editável pelo painel admin) — sem lista fixa aqui.

  void _goToVetsWithCategory(String specialty) {
    Get.find<VetsController>().selectSpecialty(specialty);
    controller.changeTab(1);
  }

  void _showCategoryModal(BuildContext context, SpecialtyDef cat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(resolveSpecialtyIcon(cat.icon),
                      color: AppColors.primary, size: 26),
                ),
                const SizedBox(width: 14),
                Text(
                  cat.label,
                  style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold,
                    color: AppColors.textDark, fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              cat.description,
              style: const TextStyle(
                fontSize: 14, color: AppColors.textMedium,
                height: 1.65, fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _goToVetsWithCategory(cat.specialty);
              },
              icon: const VvIcon(VvFn.search, size: 18, color: Colors.white),
              label: Text('Buscar profissionais de ${cat.label}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories(BuildContext context) {
    return _CategoriesSection(onTapCategory: (cat) => _showCategoryModal(context, cat));
  }

  // ── Próximo agendamento ──────────────────────────────────────────

  Widget _buildUpcomingAppointment(BuildContext context) {
    return Obx(() {
      if (controller.upcomingAppointments.isEmpty) return const SizedBox();
      final appt = controller.upcomingAppointments.first;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Próximo agendamento',
                  style: Theme.of(context).textTheme.titleMedium),
              TextButton(
                onPressed: () => Get.find<HomeController>().changeTab(2),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('Ver todos',
                    style: TextStyle(
                        color: AppColors.primary, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AppointmentCard(appointment: appt),
        ],
      );
    });
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

// Mostra as categorias em blocos de 2 linhas (6 itens) por padrão — com 15
// especialidades cadastradas hoje, o grid inteiro (5 linhas) empurrava todo o
// resto da Home pra baixo antes mesmo de rolar. "Ver todas" expande sem
// precisar de tela nova.
class _CategoriesSection extends StatefulWidget {
  final void Function(SpecialtyDef) onTapCategory;
  const _CategoriesSection({required this.onTapCategory});

  @override
  State<_CategoriesSection> createState() => _CategoriesSectionState();
}

class _CategoriesSectionState extends State<_CategoriesSection> {
  static const _collapsedCount = 6;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    final columns = scale > 1.15 ? 2 : 3;
    return Obx(() {
      final all = Get.find<TaxonomyService>().specialties;
      final showAll = _expanded || all.length <= _collapsedCount;
      final visible = showAll ? all : all.take(_collapsedCount).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Categorias', style: Vv2.t(24, 32, 700)),
              ),
              if (all.length > _collapsedCount)
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(Vv2.tapMin, Vv2.tapMin),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: Vv2.primary,
                  ),
                  child: Text(
                      showAll ? 'Ver menos' : 'Ver todas (${all.length})',
                      style: Vv2.t(14, 20, 700, color: Vv2.primary)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visible.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 116 * (scale < 1 ? 1 : scale),
            ),
            itemBuilder: (_, i) {
              final cat = visible[i];
              return _CategoryCard(
                icon: resolveSpecialtyIcon(cat.icon),
                label: cat.label,
                color: Vv2Pastel.at(i),
                onTap: () => widget.onTapCategory(cat),
              );
            },
          ),
        ],
      );
    });
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CategoryCard(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(Vv2.rCard + 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(Vv2.rCard + 8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: Vv2.surface, shape: BoxShape.circle),
                  child: VvIcon.specialty(icon, size: 24, color: Vv2.onBrand),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Vv2.t(13, 18, 700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;
  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final photo = appointment.petPhotoBase64;
    final hasPhoto = photo.isNotEmpty;

    return GestureDetector(
      onTap: () => Get.find<HomeController>().changeTab(2),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            // Avatar do pet
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                image: hasPhoto
                    ? DecorationImage(
                        image: MemoryImage(
                            base64Decode(photo.split(',').last)),
                        fit: BoxFit.cover)
                    : null,
              ),
              child: hasPhoto
                  ? null
                  : const VvIcon(VvFn.petFallback,
                      color: AppColors.primary, size: 26),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.vetName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    appointment.petName,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.primary,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_weekday(appointment.dateTime)} · ${appointment.dateTime.hour.toString().padLeft(2, '0')}:${appointment.dateTime.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMedium),
                  ),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (appointment.status == AppointmentStatus.confirmed
                        ? AppColors.success
                        : AppColors.warning)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                appointment.statusLabel,
                style: TextStyle(
                  color: appointment.status == AppointmentStatus.confirmed
                      ? AppColors.success
                      : AppColors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _weekday(DateTime dt) {
    const days = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    return '${days[dt.weekday % 7]}, ${dt.day}/${dt.month}';
  }
}
