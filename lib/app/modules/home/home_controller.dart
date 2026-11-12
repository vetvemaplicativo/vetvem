import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../routes/app_routes.dart';
import '../../data/models/appointment_model.dart';
import '../../services/analytics_service.dart';
import '../profile/profile_controller.dart';

class HomeController extends GetxController {
  final currentIndex = 0.obs;

  final upcomingAppointments = <AppointmentModel>[].obs;
  final userName = ''.obs;
  // Cidade do primeiro endereço salvo; vazio até o tutor cadastrar um endereço.
  final userCity = ''.obs;

  // Notificações reais (notifications/{uid}/pending), mais recentes primeiro.
  final notifications = <Map<String, dynamic>>[].obs;
  final unreadNotifications = 0.obs;
  DateTime? _lastNotifSeen;

  // Guia da primeira consulta
  final hasAnyAppointment = false.obs;
  final appointmentsLoaded = false.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null && args['tab'] != null) {
      currentIndex.value = args['tab'] as int;
    }
    _listenUpcoming();
    // Sincroniza nome do perfil
    final profile = Get.find<ProfileController>();
    userName.value = profile.userName.value;
    profile.userName.listen((v) => userName.value = v);
    _syncCity(profile);
    ever(profile.addresses, (_) => _syncCity(profile));
    _listenNotifications();
  }

  void _listenUpcoming() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('appointments')
        .where('tutorId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      hasAnyAppointment.value = snap.docs.isNotEmpty;
      appointmentsLoaded.value = true;
      _maybePromptRating(snap.docs);
      final active = snap.docs.where((doc) {
        final s = doc.data()['status'];
        return s == 'pending_confirmation' || s == 'confirmed';
      }).toList()
        ..sort((a, b) {
          final at = a.data()['createdAt'];
          final bt = b.data()['createdAt'];
          if (at == null || bt == null) return 0;
          return at.compareTo(bt);
        });
      upcomingAppointments.value = active.map((doc) {
        final d = doc.data();
        // Parse date "dd/MM/yyyy" + time "HH:mm"
        DateTime apptDateTime = DateTime.now();
        try {
          final dateParts = (d['date'] as String? ?? '').split('/');
          final timeParts = (d['time'] as String? ?? '00:00').split(':');
          if (dateParts.length == 3) {
            apptDateTime = DateTime(
              int.parse(dateParts[2]),
              int.parse(dateParts[1]),
              int.parse(dateParts[0]),
              int.tryParse(timeParts[0]) ?? 0,
              int.tryParse(timeParts[1]) ?? 0,
            );
          }
        } catch (_) {}
        return AppointmentModel(
          id: doc.id,
          vetId: d['vetId'] ?? '',
          vetName: d['vetName'] ?? '',
          vetSpecialty: d['serviceName'] ?? '',
          petName: d['petName'] ?? '',
          petType: d['petSpecies'] == 'cat' ? 'Gato' : d['petSpecies'] == 'dog' ? 'Cão' : 'Outro',
          dateTime: apptDateTime,
          address: d['address'] ?? '',
          status: d['status'] == 'confirmed'
              ? AppointmentStatus.confirmed
              : AppointmentStatus.scheduled,
          price: double.tryParse(
                  d['value']?.toString().replaceAll(',', '.') ?? '0') ??
              0,
          petPhotoBase64: d['petPhotoBase64'] ?? '',
        );
      }).toList();
    });
  }

  // ── Convite para avaliar ──────────────────────────────────────────────────
  // Uma vez por abertura do app: consulta CONCLUÍDA nos últimos 45 dias e ainda sem nota.
  // "Agora não" conta como adiamento; após 2 adiamentos da mesma consulta, para de perguntar.
  // No máximo um convite a cada 20 horas.
  static const _ratingBox = 'rating_prompt';
  bool _ratingPromptHandled = false;

  DateTime? _parseApptDate(String? s) {
    final p = (s ?? '').split('/');
    if (p.length != 3) return null;
    final d = int.tryParse(p[0]), m = int.tryParse(p[1]), y = int.tryParse(p[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  Future<void> _maybePromptRating(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (_ratingPromptHandled) return;
    final now = DateTime.now();
    final pending = <MapEntry<DateTime, QueryDocumentSnapshot<Map<String, dynamic>>>>[];
    for (final doc in docs) {
      final d = doc.data();
      if (d['status'] != 'completed' || d['rating'] != null) continue;
      final when = _parseApptDate(d['date'] as String?);
      if (when == null || now.difference(when).inDays > 45) continue;
      pending.add(MapEntry(when, doc));
    }
    if (pending.isEmpty) return;
    _ratingPromptHandled = true;
    try {
      await GetStorage.init(_ratingBox);
      final box = GetStorage(_ratingBox);
      final last = box.read<int>('last') ?? 0;
      if (now.millisecondsSinceEpoch - last < 20 * 3600 * 1000) return;
      pending.sort((a, b) => b.key.compareTo(a.key));
      final pick = pending.where((e) => (box.read<int>('skip_${e.value.id}') ?? 0) < 2).toList();
      if (pick.isEmpty) return;
      final doc = pick.first.value;
      final d = doc.data();
      await Future.delayed(const Duration(seconds: 2));
      if (Get.isDialogOpen == true) return;
      box.write('last', DateTime.now().millisecondsSinceEpoch);
      final vet = (d['vetName'] as String?)?.trim() ?? '';
      final go = await Get.dialog<bool>(
        AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Como foi o atendimento?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          content: Text(
            vet.isEmpty
                ? 'Sua avaliação leva menos de um minuto e ajuda outros tutores a escolher bem.'
                : 'Conte como foi a consulta com $vet. Sua avaliação leva menos de um minuto e ajuda outros tutores a escolher bem.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(onPressed: () => Get.back(result: false), child: const Text('Agora não')),
            ElevatedButton(onPressed: () => Get.back(result: true), child: const Text('Avaliar agora')),
          ],
        ),
      );
      if (go == true) {
        Get.toNamed(Routes.rating, arguments: {
          'consultationId': doc.id,
          'vetName': vet.isEmpty ? 'Veterinário' : vet,
          'petName': d['petName'] ?? 'Pet',
          'date': d['date'] ?? '',
          'specialty': d['serviceName'] ?? '',
        });
      } else {
        box.write('skip_${doc.id}', (box.read<int>('skip_${doc.id}') ?? 0) + 1);
      }
    } catch (_) {
      // convite é só um lembrete: nunca atrapalha o app
    }
  }

  void changeTab(int index) {
    if (index == 1 && currentIndex.value != 1) {
      Get.find<AnalyticsService>().logViewVetList();
    }
    currentIndex.value = index;
  }

  void _syncCity(ProfileController profile) {
    userCity.value =
        profile.addresses.isNotEmpty ? profile.addresses.first.city : '';
  }

  void _listenNotifications() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final db = FirebaseFirestore.instance;
    db.collection('users').doc(uid).get().then((s) {
      final t = s.data()?['lastNotifSeenAt'];
      _lastNotifSeen = t is Timestamp ? t.toDate() : null;
      _recountUnread();
    }).catchError((_) {});
    db
        .collection('notifications')
        .doc(uid)
        .collection('pending')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen((snap) {
      notifications.value = snap.docs.map((d) {
        final x = d.data();
        final t = x['createdAt'];
        return {
          'title': x['title'] ?? 'VetVem',
          'body': x['body'] ?? '',
          'tipo': x['tipo'],
          'createdAt': t is Timestamp ? t.toDate() : null,
        };
      }).toList();
      _recountUnread();
    });
  }

  void _recountUnread() {
    unreadNotifications.value = notifications.where((n) {
      final t = n['createdAt'] as DateTime?;
      return t != null && (_lastNotifSeen == null || t.isAfter(_lastNotifSeen!));
    }).length;
  }

  /// Chamado ao abrir o sino: zera a bolinha e lembra até onde o tutor viu.
  Future<void> markNotificationsSeen() async {
    _lastNotifSeen = DateTime.now();
    unreadNotifications.value = 0;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'lastNotifSeenAt': FieldValue.serverTimestamp()});
    } catch (_) {}
  }
}
