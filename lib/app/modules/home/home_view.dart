import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../data/models/appointment_model.dart';
import '../vets/vets_view.dart';
import '../vets/vets_controller.dart';
import '../consultas/consultas_view.dart';
import '../profile/profile_view.dart';
import '../../services/taxonomy_service.dart';
import 'home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _HomeTab(),
      const Material(child: VetsView()),
      const Material(child: ConsultasView()),
      const Material(child: ProfileView()),
    ];

    return Obx(() => AnnotatedRegion<SystemUiOverlayStyle>(
          value: controller.currentIndex.value == 0
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: IndexedStack(
              index: controller.currentIndex.value,
              children: pages,
            ),
            bottomNavigationBar: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border:
                    Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
              ),
              child: BottomNavigationBar(
                currentIndex: controller.currentIndex.value,
                onTap: controller.changeTab,
                backgroundColor: Colors.white,
                selectedItemColor: AppColors.primary,
                unselectedItemColor: AppColors.textLight,
                selectedLabelStyle: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 11),
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'Início',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.search_outlined),
                    activeIcon: Icon(Icons.search),
                    label: 'Buscar',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.receipt_long_outlined),
                    activeIcon: Icon(Icons.receipt_long),
                    label: 'Consultas',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'Perfil',
                  ),
                ],
              ),
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
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

  // ── Header laranja ───────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Obx(() => Text(
                            'Olá, ${controller.userName.value}!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          )),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Obx(() => Text(
                                controller.userCity.value,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontFamily: 'Poppins',
                                ),
                              )),
                        ],
                      ),
                    ],
                  ),
                  // Notification bell
                  GestureDetector(
                    onTap: () => _showNotifications(context),
                    child: Stack(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.notifications_outlined,
                              color: Colors.white, size: 22),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFBBC05),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'O que seu pet precisa hoje?',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 20),

              // Search bar
              GestureDetector(
                onTap: () {
                  Get.find<VetsController>().selectSpecialty('Todos');
                  controller.changeTab(1);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search, color: AppColors.textLight, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Buscar profissional...',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 14,
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
      ),
    );
  }

  // ── Notificações ─────────────────────────────────────────────────

  void _showNotifications(BuildContext context) {
    const items = [
      (Icons.check_circle_outline, AppColors.success,
          'Consulta confirmada', 'Dra. Ana Lima · amanhã · Manhã', '2 min atrás'),
      (Icons.schedule, AppColors.warning,
          'Lembrete', 'Consulta com Dr. Carlos Melo em 2 dias', '1h atrás'),
      (Icons.star_outline, AppColors.primary,
          'Avalie sua consulta', 'Como foi o atendimento da Dra. Marta?', 'Ontem'),
    ];

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
                child: ListView(
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
                            color: n.$2.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(n.$1, color: n.$2, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.$3, style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13,
                                  color: AppColors.textDark)),
                              const SizedBox(height: 3),
                              Text(n.$4, style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMedium)),
                              const SizedBox(height: 4),
                              Text(n.$5, style: const TextStyle(
                                  fontSize: 11, color: AppColors.textLight)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
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
              icon: const Icon(Icons.search, size: 18),
              label: Text('Buscar profissionais de ${cat.label}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Categorias', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 14),
        Obx(() => GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.0,
              children: Get.find<TaxonomyService>()
                  .specialties
                  .map((cat) => _CategoryCard(
                        icon: resolveSpecialtyIcon(cat.icon),
                        label: cat.label,
                        onTap: () => _showCategoryModal(context, cat),
                      ))
                  .toList(),
            )),
      ],
    );
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

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CategoryCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
                fontFamily: 'Poppins',
              ),
            ),
          ],
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
                  : const Icon(Icons.pets,
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
