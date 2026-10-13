import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
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
