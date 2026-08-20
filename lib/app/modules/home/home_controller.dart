import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../data/models/appointment_model.dart';
import '../profile/profile_controller.dart';

class HomeController extends GetxController {
  final currentIndex = 0.obs;

  final upcomingAppointments = <AppointmentModel>[].obs;
  final userName = ''.obs;
  final userCity = 'Rio de Janeiro'.obs;

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
  }

  void _listenUpcoming() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('appointments')
        .where('tutorId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
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

  void changeTab(int index) => currentIndex.value = index;
}
