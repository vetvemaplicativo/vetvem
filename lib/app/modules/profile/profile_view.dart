import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../routes/app_routes.dart';
import '../../services/cep_service.dart';
import '../../theme/app_theme.dart';
import '../terms/terms_view.dart';
import 'profile_controller.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Meus Pets'),
                  const SizedBox(height: 12),
                  Obx(() => Column(
                        children: [
                          ...controller.pets.map(
                              (p) => _PetCard(pet: p, controller: controller)),
                          _AddPetCard(controller: controller),
                        ],
                      )),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionTitle('Últimas consultas'),
                      GestureDetector(
                        onTap: () => _showFullHistory(context),
                        child: const Text('Ver tudo',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Obx(() => Column(
                        children: controller.recentConsultations
                            .take(3)
                            .map((c) => _ConsultationCard(item: c))
                            .toList(),
                      )),
                  const SizedBox(height: 28),
                  _sectionTitle('Configurações'),
                  const SizedBox(height: 12),
                  _SettingsList(controller: controller),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => _showLogoutDialog(context),
                    icon: const Icon(Icons.logout,
                        color: AppColors.error, size: 18),
                    label: const Text('Sair da conta',
                        style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error)),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text('VetVem v1.0.0',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textLight)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark));

  // ── Header ────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Material(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Obx(() => Column(
                children: [
                  GestureDetector(
                    onTap: () => _showPhotoOptions(context),
                    child: Stack(
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.2),
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: controller.userPhotoUrl.value.isEmpty
                              ? Center(
                                  child: Text(
                                    controller.userName.value.trim().isEmpty
                                        ? '?'
                                        : controller.userName.value
                                            .trim()
                                            .split(' ')
                                            .where((e) => e.isNotEmpty)
                                            .take(2)
                                            .map((e) => e[0].toUpperCase())
                                            .join(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold),
                                  ),
                                )
                              : ClipOval(child: _profileImage(controller.userPhotoUrl.value, 84)),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: controller.isUploadingPhoto.value
                              ? Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primary, width: 2),
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: const CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.primary),
                                )
                              : Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primary, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt,
                                      size: 14, color: AppColors.primary),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(controller.userName.value,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(controller.userEmail.value,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(controller.userPhone.value,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13)),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _showEditProfile(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white, width: 1.5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Editar perfil',
                        style: TextStyle(fontSize: 13)),
                  ),
                ],
              )),
        ),
      ),
    );
  }

  // ── Editar perfil ─────────────────────────────────────────────────

  void _showEditProfile(BuildContext context) {
    final nameCtrl =
        TextEditingController(text: controller.userName.value);
    final emailCtrl =
        TextEditingController(text: controller.userEmail.value);
    final phoneCtrl =
        TextEditingController(text: controller.userPhone.value);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheet(
        title: 'Editar perfil',
        child: Column(
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Nome completo',
                  prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: Icon(Icons.email_outlined)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [_PhoneMaskFormatter()],
              decoration: const InputDecoration(
                  labelText: 'Celular',
                  hintText: '(21) 9 9999-9999',
                  prefixIcon: Icon(Icons.phone_outlined)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await controller.updateProfile(
                  name: nameCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                );
                Get.back();
                _showSuccess('Perfil atualizado!');
              },
              child: const Text('Salvar alterações'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Histórico completo ────────────────────────────────────────────

  void _showFullHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text('Histórico de consultas',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              const SizedBox(height: 16),
              Expanded(
                child: Obx(() => ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount:
                          controller.recentConsultations.length,
                      itemBuilder: (_, i) => _ConsultationCard(
                          item: controller.recentConsultations[i]),
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Logout ────────────────────────────────────────────────────────

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sair da conta'),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: controller.logout,
            child: const Text('Sair',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String msg) => Get.snackbar(
        'Pronto!', msg,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 2),
        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
      );

  // ignore: unused_element
  void _showComingSoon(String feature) => Get.snackbar(
        'Em breve', '$feature estará disponível em breve.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 2),
      );

  void _showPhotoOptions(BuildContext context) {
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
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Foto de perfil',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.primary),
              ),
              title: const Text('Tirar foto'),
              subtitle: const Text('Usar a câmera do dispositivo'),
              onTap: () async {
                Get.back();
                await controller.pickAndUploadPhoto(camera: true);
              },
            ),
            ListTile(
              leading: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.photo_library_outlined,
                    color: AppColors.primary),
              ),
              title: const Text('Escolher da galeria'),
              subtitle: const Text('Selecionar uma foto existente'),
              onTap: () async {
                Get.back();
                await controller.pickAndUploadPhoto(camera: false);
              },
            ),
          ],
        ),
      ),
    );
  }
}

Widget _profileImage(String photoUrl, double size) {
  if (photoUrl.startsWith('data:image')) {
    final base64Str = photoUrl.split(',').last;
    final bytes = base64Decode(base64Str);
    return Image.memory(bytes, width: size, height: size, fit: BoxFit.cover);
  }
  return Image.network(photoUrl, width: size, height: size, fit: BoxFit.cover);
}

// ─── Pet Card ─────────────────────────────────────────────────────────────────

class _PetCard extends StatelessWidget {
  final PetProfile pet;
  final ProfileController controller;
  const _PetCard({required this.pet, required this.controller});

  @override
  Widget build(BuildContext context) {
    final emoji = pet.species == 'cat'
        ? '🐱'
        : pet.species == 'dog'
            ? '🐶'
            : pet.species == 'bird'
                ? '🐦'
                : '🐾';
    final hasPhoto = pet.photoBase64.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  image: hasPhoto
                      ? DecorationImage(
                          image: MemoryImage(base64Decode(
                              pet.photoBase64.split(',').last)),
                          fit: BoxFit.cover)
                      : null,
                ),
                child: hasPhoto
                    ? null
                    : Center(
                        child: Text(emoji,
                            style: const TextStyle(fontSize: 28))),
              ),
              if (hasPhoto)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: const Color(0xFFE5E7EB), width: 1),
                    ),
                    child: Center(
                        child: Text(emoji,
                            style: const TextStyle(fontSize: 12))),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pet.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textDark)),
                const SizedBox(height: 3),
                Text(pet.breed,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMedium)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (pet.ageLabel.isNotEmpty) _MiniChip(pet.ageLabel),
                    _MiniChip(pet.sex),
                    if (pet.castrated)
                      _MiniChip('Castrado', color: AppColors.success),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _showPetConsultations(context, pet),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_note_rounded,
                            size: 13, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text('Ver consultas',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert,
                color: AppColors.textLight, size: 20),
            onPressed: () => _showPetOptions(context),
          ),
        ],
      ),
    );
  }

  void _showPetConsultations(BuildContext context, PetProfile pet) {
    final consultations = controller.recentConsultations
        .where((c) => c.petName == pet.name && c.status == 'completed')
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, sc) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  const Icon(Icons.event_note_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Consultas de ${pet.name}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                ]),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              if (consultations.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 48, color: AppColors.textLight),
                        const SizedBox(height: 12),
                        const Text('Nenhuma consulta concluída', style: TextStyle(color: AppColors.textMedium)),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: sc,
                    padding: const EdgeInsets.all(16),
                    itemCount: consultations.length,
                    itemBuilder: (_, i) {
                      final item = consultations[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: item.prontuario != null
                              ? () {
                                  Get.back();
                                  Get.toNamed(Routes.prontuario, arguments: {'item': item});
                                }
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.vetName,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textDark)),
                                    const SizedBox(height: 2),
                                    Text(item.specialty,
                                        style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
                                    const SizedBox(height: 4),
                                    Text(item.date,
                                        style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                                  ],
                                ),
                              ),
                              if (item.prontuario != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Prontuário',
                                      style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                                )
                              else
                                const Icon(Icons.lock_outline, size: 16, color: AppColors.textLight),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPetOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text(pet.name,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 20),
            _OptionTile(
              icon: Icons.edit_outlined,
              label: 'Editar informações',
              onTap: () {
                Get.back();
                _showEditPet(context);
              },
            ),
            const Divider(height: 1),
            _OptionTile(
              icon: Icons.delete_outline,
              label: 'Remover pet',
              color: AppColors.error,
              onTap: () {
                Get.back();
                _confirmRemove(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditPetSheet(pet: pet, controller: controller),
    );
  }
  void _confirmRemove(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remover ${pet.name}'),
        content: Text(
            'Tem certeza que deseja remover ${pet.name} da sua conta?'),
        actions: [
          TextButton(
              onPressed: () => Get.back(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              controller.removePet(pet);
              Get.back();
            },
            child: const Text('Remover',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip(this.label, {this.color = AppColors.textMedium});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ─── Edit Pet Sheet ───────────────────────────────────────────────────────────

class _EditPetSheet extends StatefulWidget {
  final PetProfile pet;
  final ProfileController controller;
  const _EditPetSheet({required this.pet, required this.controller});

  @override
  State<_EditPetSheet> createState() => _EditPetSheetState();
}

class _EditPetSheetState extends State<_EditPetSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _breedCtrl;
  late String _photoBase64;
  bool _pickingPhoto = false;
  int? _birthYear;
  int? _birthMonth;

  static const _months = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.pet.name);
    _breedCtrl = TextEditingController(text: widget.pet.breed);
    _photoBase64 = widget.pet.photoBase64;
    _birthYear = widget.pet.birthYear;
    _birthMonth = widget.pet.birthMonth;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _breedCtrl.dispose();
    super.dispose();
  }

  String _calcAge(int year, int month) {
    final now = DateTime.now();
    int months = (now.year - year) * 12 + (now.month - month);
    if (months < 0) months = 0;
    final years = months ~/ 12;
    final rem = months % 12;
    if (years == 0) return '$months ${months == 1 ? 'mês' : 'meses'}';
    if (rem == 0) return '$years ${years == 1 ? 'ano' : 'anos'}';
    return '$years ${years == 1 ? 'ano' : 'anos'} e $rem ${rem == 1 ? 'mês' : 'meses'}';
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    int selectedYear = _birthYear ?? now.year;
    int selectedMonth = _birthMonth ?? now.month;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Mês e ano de nascimento',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ano
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ano', style: TextStyle(fontWeight: FontWeight.w600)),
                  Row(children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: selectedYear > 2000
                          ? () => setS(() => selectedYear--)
                          : null,
                    ),
                    Text('$selectedYear',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: selectedYear < now.year
                          ? () => setS(() => selectedYear++)
                          : null,
                    ),
                  ]),
                ],
              ),
              const SizedBox(height: 8),
              // Mês em grid
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List.generate(12, (i) {
                  final sel = selectedMonth == i + 1;
                  // Bloqueia meses futuros no ano atual
                  final disabled = selectedYear == now.year && i + 1 > now.month;
                  return GestureDetector(
                    onTap: disabled ? null : () => setS(() => selectedMonth = i + 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : (disabled ? const Color(0xFFF3F4F6) : const Color(0xFFF9FAFB)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sel ? AppColors.primary : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Text(
                        _months[i].substring(0, 3),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                          color: sel ? Colors.white : (disabled ? const Color(0xFFD1D5DB) : AppColors.textDark),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                setState(() {
                  _birthYear = selectedYear;
                  _birthMonth = selectedMonth;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    setState(() => _pickingPhoto = true);
    final photo = await widget.controller.pickPetPhoto();
    setState(() {
      if (photo.isNotEmpty) _photoBase64 = photo;
      _pickingPhoto = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final emoji = widget.pet.species == 'cat'
        ? '🐱'
        : widget.pet.species == 'dog'
            ? '🐶'
            : widget.pet.species == 'bird'
                ? '🐦'
                : '🐾';
    final hasPhoto = _photoBase64.isNotEmpty;

    return _BottomSheet(
      title: 'Editar ${widget.pet.name}',
      child: Column(
        children: [
          // Foto
          Center(
            child: GestureDetector(
              onTap: _pickingPhoto ? null : _pickPhoto,
              child: Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      image: hasPhoto
                          ? DecorationImage(
                              image: MemoryImage(
                                  base64Decode(_photoBase64.split(',').last)),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: hasPhoto
                        ? null
                        : _pickingPhoto
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : Center(
                                child: Text(emoji,
                                    style: const TextStyle(fontSize: 32))),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 24, height: 24,
                      decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text('Toque para alterar a foto',
                style: TextStyle(fontSize: 11, color: AppColors.textLight)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _breedCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Raça'),
          ),
          const SizedBox(height: 14),
          // Nascimento
          GestureDetector(
            onTap: _pickBirthDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cake_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _birthYear != null && _birthMonth != null
                          ? '${_months[_birthMonth! - 1]} de $_birthYear'
                          : 'Mês e ano de nascimento',
                      style: TextStyle(
                        fontSize: 14,
                        color: _birthYear != null ? AppColors.textDark : AppColors.textLight,
                      ),
                    ),
                  ),
                  if (_birthYear != null && _birthMonth != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _calcAge(_birthYear!, _birthMonth!),
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const Icon(Icons.chevron_right, color: AppColors.textLight, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              widget.controller.updatePet(
                widget.pet,
                _nameCtrl.text.trim(),
                _breedCtrl.text.trim(),
                birthYear: _birthYear,
                birthMonth: _birthMonth,
                photoBase64: _photoBase64,
              );
              Get.back();
              Get.snackbar(
                'Pronto!', 'Dados de ${_nameCtrl.text} atualizados.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: AppColors.success,
                colorText: Colors.white,
                margin: const EdgeInsets.all(16),
                borderRadius: 12,
                duration: const Duration(seconds: 2),
              );
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

class _AddPetCard extends StatelessWidget {
  final ProfileController controller;
  const _AddPetCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAddPet(context),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Adicionar pet',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  void _showAddPet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddPetSheet(controller: controller),
    );
  }
}

// ─── Add Pet Sheet (StatefulWidget — sem Obx) ────────────────────────────────

class _AddPetSheet extends StatefulWidget {
  final ProfileController controller;
  const _AddPetSheet({required this.controller});

  @override
  State<_AddPetSheet> createState() => _AddPetSheetState();
}

class _AddPetSheetState extends State<_AddPetSheet> {
  final _nameCtrl = TextEditingController();
  final _breedCtrl = TextEditingController();
  String _species = 'dog';
  String _sex = 'Macho';
  bool _castrated = false;
  String _photoBase64 = '';
  bool _pickingPhoto = false;
  int? _birthYear;
  int? _birthMonth;

  static const _months = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _breedCtrl.dispose();
    super.dispose();
  }

  String _calcAge(int year, int month) {
    final now = DateTime.now();
    int months = (now.year - year) * 12 + (now.month - month);
    if (months < 0) months = 0;
    final years = months ~/ 12;
    final rem = months % 12;
    if (years == 0) return '$months ${months == 1 ? 'mês' : 'meses'}';
    if (rem == 0) return '$years ${years == 1 ? 'ano' : 'anos'}';
    return '$years ${years == 1 ? 'ano' : 'anos'} e $rem ${rem == 1 ? 'mês' : 'meses'}';
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    int selectedYear = _birthYear ?? now.year;
    int selectedMonth = _birthMonth ?? now.month;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Mês e ano de nascimento',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ano', style: TextStyle(fontWeight: FontWeight.w600)),
                  Row(children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: selectedYear > 2000 ? () => setS(() => selectedYear--) : null,
                    ),
                    Text('$selectedYear',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: selectedYear < now.year ? () => setS(() => selectedYear++) : null,
                    ),
                  ]),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List.generate(12, (i) {
                  final sel = selectedMonth == i + 1;
                  final disabled = selectedYear == now.year && i + 1 > now.month;
                  return GestureDetector(
                    onTap: disabled ? null : () => setS(() => selectedMonth = i + 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : (disabled ? const Color(0xFFF3F4F6) : const Color(0xFFF9FAFB)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: sel ? AppColors.primary : const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        _months[i].substring(0, 3),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                          color: sel ? Colors.white : (disabled ? const Color(0xFFD1D5DB) : AppColors.textDark),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                setState(() {
                  _birthYear = selectedYear;
                  _birthMonth = selectedMonth;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    setState(() => _pickingPhoto = true);
    final photo = await widget.controller.pickPetPhoto();
    setState(() {
      _photoBase64 = photo;
      _pickingPhoto = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheet(
      title: 'Novo pet',
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto do pet
            Center(
              child: GestureDetector(
                onTap: _pickingPhoto ? null : _pickPhoto,
                child: Stack(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.08),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 2),
                        image: _photoBase64.isNotEmpty
                            ? DecorationImage(
                                image: MemoryImage(
                                    base64Decode(_photoBase64.split(',').last)),
                                fit: BoxFit.cover)
                            : null,
                      ),
                      child: _photoBase64.isEmpty
                          ? _pickingPhoto
                              ? const CircularProgressIndicator(strokeWidth: 2)
                              : const Icon(Icons.pets,
                                  color: AppColors.primary, size: 36)
                          : null,
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 26, height: 26,
                        decoration: const BoxDecoration(
                            color: AppColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('Foto do pet (opcional)',
                  style: TextStyle(fontSize: 12, color: AppColors.textLight)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome do pet'),
            ),
            const SizedBox(height: 14),
            const Text('Espécie',
                style: TextStyle(fontSize: 13, color: AppColors.textMedium)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final s in [
                  ('dog', '🐶 Cão'),
                  ('cat', '🐱 Gato'),
                  ('bird', '🐦 Ave'),
                  ('other', '🐾 Outro'),
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _species = s.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _species == s.$1 ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _species == s.$1
                                    ? AppColors.primary
                                    : const Color(0xFFE5E7EB)),
                          ),
                          child: Text(s.$2,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: _species == s.$1
                                      ? Colors.white
                                      : AppColors.textDark)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _breedCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Raça'),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _pickBirthDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cake_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _birthYear != null && _birthMonth != null
                            ? '${_months[_birthMonth! - 1]} de $_birthYear'
                            : 'Mês e ano de nascimento',
                        style: TextStyle(
                          fontSize: 14,
                          color: _birthYear != null ? AppColors.textDark : AppColors.textLight,
                        ),
                      ),
                    ),
                    if (_birthYear != null && _birthMonth != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _calcAge(_birthYear!, _birthMonth!),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    const Icon(Icons.chevron_right, color: AppColors.textLight, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Sexo',
                style: TextStyle(fontSize: 13, color: AppColors.textMedium)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final sx in ['Macho', 'Fêmea'])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _sex = sx),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _sex == sx ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _sex == sx
                                    ? AppColors.primary
                                    : const Color(0xFFE5E7EB)),
                          ),
                          child: Text(sx,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _sex == sx
                                      ? Colors.white
                                      : AppColors.textDark)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _castrated = !_castrated),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _castrated ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: _castrated
                              ? AppColors.primary
                              : const Color(0xFFD1D5DB),
                          width: 2),
                    ),
                    child: _castrated
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  const Text('Castrado/a',
                      style: TextStyle(fontSize: 14, color: AppColors.textDark)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (_nameCtrl.text.trim().isEmpty) return;
                widget.controller.addPet(PetProfile(
                  name: _nameCtrl.text.trim(),
                  species: _species,
                  breed: _breedCtrl.text.trim().isEmpty
                      ? 'Sem raça definida'
                      : _breedCtrl.text.trim(),
                  birthYear: _birthYear,
                  birthMonth: _birthMonth,
                  sex: _sex,
                  castrated: _castrated,
                  photoBase64: _photoBase64,
                ));
                Get.back();
                Get.snackbar(
                  'Pronto!', '${_nameCtrl.text} adicionado com sucesso!',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppColors.success,
                  colorText: Colors.white,
                  margin: const EdgeInsets.all(16),
                  borderRadius: 12,
                  duration: const Duration(seconds: 2),
                );
              },
              child: const Text('Adicionar pet'),
            ),
          ],
        ),
    );
  }
}

// ─── Consultation Card ────────────────────────────────────────────────────────


class _ConsultationCard extends StatelessWidget {
  final ConsultationHistory item;
  const _ConsultationCard({required this.item});

  Widget _buildPetPhoto(String photo) {
    ImageProvider? img;
    if (photo.isNotEmpty) {
      try {
        img = MemoryImage(base64Decode(
            photo.contains(',') ? photo.split(',').last : photo));
      } catch (_) {}
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        image: img != null
            ? DecorationImage(image: img, fit: BoxFit.cover)
            : null,
      ),
      child: img == null
          ? const Icon(Icons.pets, color: AppColors.primary, size: 22)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = item.status == 'completed';
    final isCancelled = item.status == 'cancelled' || item.status == 'rejected';
    final isConfirmed = item.status == 'confirmed';
    final statusColor = isCompleted
        ? AppColors.success
        : isCancelled
            ? AppColors.error
            : isConfirmed
                ? const Color(0xFF1A73E8)
                : AppColors.warning;
    final statusLabel = isCompleted
        ? 'Concluída'
        : isCancelled
            ? (item.status == 'rejected' ? 'Recusada' : 'Cancelada')
            : isConfirmed
                ? 'Confirmada'
                : 'Aguardando';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          _buildPetPhoto(item.petPhotoBase64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.vetName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text(item.petName.isNotEmpty ? '${item.petName} · ${item.specialty}' : item.specialty,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMedium)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.calendar_today,
                      size: 11, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Text('${item.date}${item.time.isNotEmpty ? ' · ${item.time}' : ''}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textLight)),
                ]),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor)),
          ),
        ],
      ),
    );
  }
}

// ─── Settings List ────────────────────────────────────────────────────────────

class _SettingsList extends StatelessWidget {
  final ProfileController controller;
  const _SettingsList({required this.controller});

  static const _items = [
    (Icons.person_outline,         'Editar perfil',           'edit'),
    (Icons.notifications_outlined, 'Notificações',            'notifications'),
    (Icons.location_on_outlined,   'Endereços salvos',        'addresses'),
    (Icons.payment_outlined,       'Métodos de pagamento',    'payment'),
    (Icons.help_outline,           'Ajuda e suporte',         'help'),
    (Icons.privacy_tip_outlined,   'Privacidade',             'privacy'),
    (Icons.description_outlined,   'Termos de Uso',           'terms'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: _items.indexed.map(((int, (IconData, String, String)) e) {
          final (i, (icon, label, action)) = e;
          return Column(
            children: [
              ListTile(
                leading: Icon(icon, color: AppColors.primary, size: 20),
                title: Text(label,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textDark)),
                trailing: const Icon(Icons.arrow_forward_ios,
                    size: 13, color: AppColors.textLight),
                onTap: () {
                  switch (action) {
                    case 'edit':
                      _showEditProfile(context);
                    case 'notifications':
                      _showNotifications(context);
                    case 'addresses':
                      _showAddresses(context);
                    case 'payment':
                      _showPaymentMethods(context);
                    case 'help':
                      _showHelp(context);
                    case 'privacy':
                      _showPrivacy(context);
                    case 'terms':
                      Get.to(() => const TermsView(readOnly: true));
                  }
                },
              ),
              if (i < _items.length - 1)
                const Divider(height: 1, indent: 56, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showEditProfile(BuildContext context) {
    final nameCtrl =
        TextEditingController(text: controller.userName.value);
    final emailCtrl =
        TextEditingController(text: controller.userEmail.value);
    final phoneCtrl =
        TextEditingController(text: controller.userPhone.value);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheet(
        title: 'Editar perfil',
        child: Column(
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Nome completo',
                  prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: Icon(Icons.email_outlined)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [_PhoneMaskFormatter()],
              decoration: const InputDecoration(
                  labelText: 'Celular',
                  hintText: '(21) 9 9999-9999',
                  prefixIcon: Icon(Icons.phone_outlined)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await controller.updateProfile(
                  name: nameCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                );
                Get.back();
                Get.snackbar('Pronto!', 'Perfil atualizado!',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppColors.success,
                    colorText: Colors.white,
                    margin: const EdgeInsets.all(16),
                    borderRadius: 12,
                    duration: const Duration(seconds: 2),
                    icon: const Icon(Icons.check_circle_outline,
                        color: Colors.white));
              },
              child: const Text('Salvar alterações'),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheet(
        title: 'Notificações',
        child: _NotificationsSheet(),
      ),
    );
  }

  void _showAddresses(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddressesSheet(controller: controller),
    );
  }

  void _showPaymentMethods(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PaymentMethodsSheet(controller: controller),
    );
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheet(
        title: 'Ajuda e suporte',
        child: Column(
          children: [
            _HelpTile(
              icon: Icons.chat_bubble_outline,
              title: 'Chat com suporte',
              subtitle: 'Atendimento pelo WhatsApp',
              onTap: () async {
                final uri = Uri.parse('https://wa.me/5521999999999?text=Ol%C3%A1%2C%20preciso%20de%20ajuda%20com%20o%20VetVem');
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
            const Divider(height: 1),
            _HelpTile(
              icon: Icons.email_outlined,
              title: 'Enviar e-mail',
              subtitle: 'suporte@vetvem.com.br',
              onTap: () async {
                final uri = Uri(
                  scheme: 'mailto',
                  path: 'suporte@vetvem.com.br',
                  queryParameters: {'subject': 'Suporte VetVem'},
                );
                await launchUrl(uri);
              },
            ),
            const Divider(height: 1),
            _HelpTile(
              icon: Icons.quiz_outlined,
              title: 'Perguntas frequentes',
              subtitle: 'Respostas para as dúvidas mais comuns',
              onTap: () {
                Get.back();
                _showFaq(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFaq(BuildContext context) {
    const faqs = [
      ('Como agendar uma consulta?',
          'Na tela "Buscar", escolha um veterinário e toque em "Agendar consulta". Selecione seu pet, data e horário, e confirme o pagamento.'),
      ('Posso cancelar um agendamento?',
          'Sim. Na aba "Consultas", toque em "Cancelar" na consulta desejada. Cancelamentos feitos com menos de 2 horas de antecedência podem ter taxa.'),
      ('Como cadastrar um pet?',
          'No seu Perfil, toque em "+ Adicionar pet" e preencha os dados do seu animal.'),
      ('O veterinário vai até minha casa?',
          'Sim! O VetVem é um serviço de atendimento domiciliar. O profissional vai até o endereço informado no agendamento.'),
      ('Como funciona o pagamento?',
          'Aceitamos Pix e cartão de crédito. Você escolhe a forma de pagamento ao confirmar o agendamento.'),
      ('Posso avaliar o veterinário?',
          'Após a conclusão da consulta, você receberá uma notificação para avaliar o atendimento.'),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, scroll) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text('Perguntas frequentes',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  itemCount: faqs.length,
                  separatorBuilder: (context2, i2) => const SizedBox(height: 10),
                  itemBuilder: (context2, i) => _FaqItem(q: faqs[i].$1, a: faqs[i].$2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (_, scroll) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Privacidade',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scroll,
                  children: const [
                    Text('Coleta de dados',
                        style: TextStyle(fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    SizedBox(height: 8),
                    Text(
                      'Coletamos apenas os dados necessários para o funcionamento do app: nome, e-mail, telefone e localização aproximada para encontrar veterinários próximos.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.6),
                    ),
                    SizedBox(height: 16),
                    Text('Compartilhamento',
                        style: TextStyle(fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    SizedBox(height: 8),
                    Text(
                      'Seus dados são compartilhados apenas com o veterinário agendado, exclusivamente para fins do atendimento.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.6),
                    ),
                    SizedBox(height: 16),
                    Text('Exclusão de dados',
                        style: TextStyle(fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    SizedBox(height: 8),
                    Text(
                      'Você pode solicitar a exclusão da sua conta e de todos os dados a qualquer momento pelo suporte.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  void _showAddAddressForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddAddressSheet(controller: controller),
    );
  }

  // ignore: unused_element
  void _showAddCardForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddCardSheet(controller: controller),
    );
  }
}

// ─── Add Address Sheet ────────────────────────────────────────────────────────

class _AddAddressSheet extends StatefulWidget {
  final ProfileController controller;
  const _AddAddressSheet({required this.controller});
  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _cep = TextEditingController();
  final _street = TextEditingController();
  final _number = TextEditingController();
  final _complement = TextEditingController();
  final _neighborhood = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  String _label = 'Casa';
  bool _loadingCep = false;

  Future<void> _lookupCep(String value) async {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) return;
    setState(() => _loadingCep = true);
    try {
      final result = await lookupCep(digits);
      if (result == null) {
        Get.snackbar('CEP não encontrado', 'Verifique o CEP informado.',
            snackPosition: SnackPosition.TOP);
        return;
      }
      setState(() {
        _street.text = result.street;
        _neighborhood.text = result.neighborhood;
        _city.text = result.city;
        _state.text = result.state;
      });
    } catch (_) {
      Get.snackbar('Sem conexão',
          'Não foi possível buscar o CEP. Preencha o endereço manualmente.',
          snackPosition: SnackPosition.TOP);
    } finally {
      if (mounted) setState(() => _loadingCep = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_cep, _street, _number, _complement, _neighborhood, _city, _state]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 32 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Adicionar endereço',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 20),
            // Label chips
            Row(children: ['Casa', 'Trabalho', 'Outro'].map((l) {
              final sel = l == _label;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _label = l),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(l, style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : AppColors.textMedium)),
                  ),
                ),
              );
            }).toList()),
            const SizedBox(height: 16),
            _Field(
              ctrl: _cep,
              label: 'CEP',
              hint: '00000-000',
              keyboard: TextInputType.number,
              onChanged: _lookupCep,
              suffix: _loadingCep
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : null,
            ),
            const SizedBox(height: 12),
            _Field(ctrl: _street, label: 'Rua / Avenida', hint: 'Nome da rua'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(flex: 2, child: _Field(ctrl: _number, label: 'Número',
                  hint: '123', keyboard: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: _Field(ctrl: _complement,
                  label: 'Complemento', hint: 'Apto, Bloco...')),
            ]),
            const SizedBox(height: 12),
            _Field(ctrl: _neighborhood, label: 'Bairro', hint: 'Nome do bairro'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(flex: 3, child: _Field(ctrl: _city, label: 'Cidade',
                  hint: 'Rio de Janeiro')),
              const SizedBox(width: 12),
              Expanded(flex: 1, child: _Field(ctrl: _state, label: 'UF',
                  hint: 'RJ')),
            ]),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (_street.text.trim().isEmpty || _number.text.trim().isEmpty) {
                  Get.snackbar('Campo obrigatório', 'Preencha rua e número',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: AppColors.error,
                      colorText: Colors.white);
                  return;
                }
                widget.controller.addAddress(SavedAddress(
                  label: _label,
                  cep: _cep.text.trim(),
                  street: _street.text.trim(),
                  number: _number.text.trim(),
                  complement: _complement.text.trim(),
                  neighborhood: _neighborhood.text.trim(),
                  city: _city.text.trim(),
                  state: _state.text.trim(),
                ));
                Get.back();
                Get.snackbar('Endereço salvo', '$_label adicionado com sucesso',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppColors.success,
                    colorText: Colors.white);
              },
              child: const Text('Salvar endereço'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add Card Sheet ───────────────────────────────────────────────────────────

class _AddCardSheet extends StatefulWidget {
  final ProfileController controller;
  const _AddCardSheet({required this.controller});
  @override
  State<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<_AddCardSheet> {
  final _number = TextEditingController();
  final _holder = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();

  @override
  void dispose() {
    for (final c in [_number, _holder, _expiry, _cvv]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 32 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Adicionar cartão',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 20),
            _Field(ctrl: _number, label: 'Número do cartão',
                hint: '0000 0000 0000 0000', keyboard: TextInputType.number,
                inputFormatters: [_CardNumberFmt()]),
            const SizedBox(height: 12),
            _Field(ctrl: _holder, label: 'Nome no cartão',
                hint: 'Como está no cartão',
                textCapitalization: TextCapitalization.characters),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Field(ctrl: _expiry, label: 'Validade',
                  hint: 'MM/AA', keyboard: TextInputType.number,
                  inputFormatters: [_ExpiryFmt()])),
              const SizedBox(width: 12),
              Expanded(child: _Field(ctrl: _cvv, label: 'CVV',
                  hint: '•••', keyboard: TextInputType.number,
                  obscure: true)),
            ]),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final digits = _number.text.replaceAll(RegExp(r'\D'), '');
                if (digits.length < 16) {
                  Get.snackbar('Erro', 'Número do cartão inválido',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: AppColors.error,
                      colorText: Colors.white);
                  return;
                }
                if (_holder.text.trim().isEmpty) {
                  Get.snackbar('Erro', 'Informe o nome no cartão',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: AppColors.error,
                      colorText: Colors.white);
                  return;
                }
                final last4 = digits.substring(digits.length - 4);
                final brand = ProfileController.detectBrand(digits);
                widget.controller.addCard(SavedCard(
                  holderName: _holder.text.trim().toUpperCase(),
                  lastFour: last4,
                  expiry: _expiry.text,
                  brand: brand,
                ));
                Get.back();
                Get.snackbar('Cartão salvo',
                    '$brand •••• $last4 adicionado',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppColors.success,
                    colorText: Colors.white);
              },
              child: const Text('Salvar cartão'),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple input field helper
// ─── Addresses Sheet ─────────────────────────────────────────────────────────

class _AddressesSheet extends StatelessWidget {
  final ProfileController controller;
  const _AddressesSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _BottomSheet(
      title: 'Endereços salvos',
      child: Obx(() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...controller.addresses.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    icon: a.label == 'Casa'
                        ? Icons.home_outlined
                        : a.label == 'Trabalho'
                            ? Icons.business_outlined
                            : Icons.location_on_outlined,
                    label: a.label,
                    value: a.fullLine,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.error, size: 20),
                  onPressed: () => controller.removeAddress(a),
                ),
              ],
            ),
          )),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _AddAddressSheet(controller: controller),
              );
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Adicionar endereço'),
          ),
        ],
      )),
    );
  }
}

// ─── Payment Methods Sheet ────────────────────────────────────────────────────

class _PaymentMethodsSheet extends StatelessWidget {
  final ProfileController controller;
  const _PaymentMethodsSheet({required this.controller});

  void _confirmRemove(BuildContext context, SavedCard card) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir cartão?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: Text(
            '${card.brand} •••• ${card.lastFour} será removido dos seus métodos de pagamento.',
            style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textMedium)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.removeCard(card);
            },
            child: const Text('Excluir',
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheet(
      title: 'Métodos de pagamento',
      child: Obx(() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...controller.savedCards.map((card) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    icon: Icons.credit_card_outlined,
                    label: '${card.brand} •••• ${card.lastFour}',
                    value: '${card.holderName} · Válido até ${card.expiry}',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.error, size: 20),
                  onPressed: () => _confirmRemove(context, card),
                ),
              ],
            ),
          )),
          if (controller.savedCards.length < ProfileController.maxCards)
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _AddCardSheet(controller: controller),
                );
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Adicionar cartão'),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Limite de 5 cartões atingido. Exclua um para adicionar outro.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
            ),
        ],
      )),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final TextInputType keyboard;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool obscure;
  final void Function(String)? onChanged;
  final Widget? suffix;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.keyboard = TextInputType.text,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.obscure = false,
    this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: AppColors.textMedium)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          obscureText: obscure,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffix != null ? Padding(
              padding: const EdgeInsets.all(12),
              child: suffix,
            ) : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          ),
        ),
      ],
    );
  }
}

class _PhoneMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue val) {
    final digits = val.text.replaceAll(RegExp(r'\D'), '');
    final d = digits.length > 11 ? digits.substring(0, 11) : digits;
    final buf = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 0) buf.write('(');
      if (i == 2) buf.write(') ');
      if (i == 3 && d.length == 11) buf.write(' ');
      if (i == 6 && d.length <= 10) buf.write('-');
      if (i == 7 && d.length == 11) buf.write('-');
      buf.write(d[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class _CardNumberFmt extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue val) {
    final digits = val.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 16 ? digits.substring(0, 16) : digits;
    final buf = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(limited[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class _ExpiryFmt extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue val) {
    final digits = val.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 4 ? digits.substring(0, 4) : digits;
    final text = limited.length > 2
        ? '${limited.substring(0, 2)}/${limited.substring(2)}'
        : limited;
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

// ─── FAQ Item ─────────────────────────────────────────────────────────────────

class _FaqItem extends StatefulWidget {
  final String q, a;
  const _FaqItem({required this.q, required this.a});
  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _open ? AppColors.primary.withValues(alpha: 0.3) : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(child: Text(widget.q,
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14,
                          color: _open ? AppColors.primary : AppColors.textDark))),
                  Icon(_open ? Icons.expand_less : Icons.expand_more,
                      color: _open ? AppColors.primary : AppColors.textLight),
                ],
              ),
            ),
          ),
          if (_open) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Text(widget.a, style: const TextStyle(
                  fontSize: 13, color: AppColors.textMedium, height: 1.6)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Option Tile ──────────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.textDark,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: TextStyle(color: color, fontSize: 15)),
      onTap: onTap,
    );
  }
}

// ─── Bottom Sheet wrapper ─────────────────────────────────────────────────────

// ─── Notifications Sheet ──────────────────────────────────────────────────────

class _NotificationsSheet extends StatefulWidget {
  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  bool _consultas = true;
  bool _lembretes = true;
  bool _promocoes = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SwitchTile('Confirmações de consulta', _consultas,
            (v) => setState(() => _consultas = v)),
        const Divider(height: 1),
        _SwitchTile('Lembretes de agendamento', _lembretes,
            (v) => setState(() => _lembretes = v)),
        const Divider(height: 1),
        _SwitchTile('Promoções e novidades', _promocoes,
            (v) => setState(() => _promocoes = v)),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            Get.back();
            Get.snackbar('Pronto!', 'Preferências salvas.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: AppColors.success,
                colorText: Colors.white,
                margin: const EdgeInsets.all(16),
                borderRadius: 12,
                duration: const Duration(seconds: 2));
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label,
          style: const TextStyle(fontSize: 14, color: AppColors.textDark)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.primary,
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMedium)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _HelpTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(title,
          style: const TextStyle(fontSize: 14, color: AppColors.textDark)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
      trailing: const Icon(Icons.arrow_forward_ios,
          size: 13, color: AppColors.textLight),
      onTap: onTap,
    );
  }
}

// ─── Bottom Sheet wrapper ─────────────────────────────────────────────────────

class _BottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  const _BottomSheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // padding dinâmico empurra conteúdo acima do teclado
      padding: EdgeInsets.fromLTRB(24, 12, 24, 32 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}
