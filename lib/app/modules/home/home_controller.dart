import '../../widgets/auth_widgets.dart';
import '../../widgets/vv_sheet.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../routes/app_routes.dart';
import '../../data/models/appointment_model.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../services/region_service.dart';
import '../../services/municipios_coords.dart';
import '../vets/vets_controller.dart';
import 'region_picker_sheet.dart';
import '../profile/profile_controller.dart';

class HomeController extends GetxController {
  final currentIndex = 0.obs;

  bool get isGuest => Get.find<AuthService>().isGuest;

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
    // Sincroniza nome do perfil (o cadastro abaixo também atualiza)
    final profile = Get.find<ProfileController>();
    userName.value = profile.userName.value;
    // Instância única na sessão (HomeBinding: permanent). Ao entrar/sair da
    // conta a Home era recriada e a tela ficava com a instância antiga, já
    // descartada: endereço novo não aparecia, escutas ficavam órfãs. Agora
    // as escutas são refeitas aqui quando a conta muda.
    _onAccount(FirebaseAuth.instance.currentUser);
    _authSub = FirebaseAuth.instance.userChanges().listen(_onAccount);
  }

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;
  StreamSubscription? _upcomingSub;
  StreamSubscription? _notifSub;
  String? _userDocUid = '-';

  void _onAccount(User? u) {
    final uid = (u == null || u.isAnonymous) ? null : u.uid;
    if (uid == _userDocUid) return;
    final entrou = _userDocUid != '-' && uid != null;
    _userDocUid = uid;
    _userDocSub?.cancel();
    _upcomingSub?.cancel();
    _notifSub?.cancel();
    _userDocSub = _upcomingSub = _notifSub = null;
    upcomingAppointments.clear();
    notifications.clear();
    unreadNotifications.value = 0;
    hasAnyAppointment.value = false;
    appointmentsLoaded.value = false;
    if (uid == null) {
      userCity.value = '';
      return;
    }
    _listenUpcoming(uid);
    _listenNotifications(uid);
    _listenUserDoc(uid);
    if (entrou) {
      // Acabou de entrar na conta (visitante → login/cadastro): volta ao
      // Início e retoma o agendamento pedido, se houver.
      currentIndex.value = 0;
      Future.delayed(const Duration(milliseconds: 600), _resumePendingBooking);
    }
  }

  void _listenUserDoc(String uid) {
    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) async {
      final d = doc.data();
      final nome = (d?['name'] ?? '').toString().trim();
      if (nome.isNotEmpty) userName.value = nome;
      final addrs = List<Map<String, dynamic>>.from(d?['addresses'] ?? []);
      if (addrs.isEmpty) {
        userCity.value = '';
        return;
      }
      final a = addrs.first;
      final cidade = (a['city'] ?? '').toString().trim();
      await MunicipiosCoords.ensureLoaded();
      userCity.value =
          MunicipiosCoords.canonical((a['state'] ?? '').toString(), cidade)?.$2 ??
              cidade;
    }, onError: (_) {});
  }

  @override
  void onClose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    _upcomingSub?.cancel();
    _notifSub?.cancel();
    super.onClose();
  }

  @override
  void onReady() {
    super.onReady();
    // App aberto já logado com um agendamento pendente (raro). O caso comum
    // — visitante que entra na conta — é tratado em _onAccount.
    _resumePendingBooking();
  }

  /// Visitante que pediu para agendar, criou a conta/entrou e voltou à Home:
  /// reabre o profissional e segue para o agendamento.
  Future<void> _resumePendingBooking() async {
    final auth = Get.find<AuthService>();
    final vetId = auth.pendingVetId;
    final u = FirebaseAuth.instance.currentUser;
    if (vetId == null || u == null || u.isAnonymous) return;
    auth.pendingVetId = null;
    final vets = Get.find<VetsController>();
    for (var i = 0; i < 40 && (vets.isLoading.value || vets.allVets.isEmpty); i++) {
      await Future.delayed(const Duration(milliseconds: 250));
    }
    final idx = vets.allVets.indexWhere((v) => v.id == vetId);
    if (idx < 0) return;
    final vet = vets.allVets[idx];
    vets.openVetDetail(vet);
    vets.scheduleVet(vet);
  }

  /// Texto da linha de local do cabeçalho.
  String get locationLabel {
    if (isGuest) {
      final r = Get.find<RegionService>();
      return r.hasRegion ? r.label : 'Escolha sua cidade';
    }
    return userCity.value.isEmpty
        ? 'Informe seu endereço no Perfil'
        : userCity.value;
  }

  Future<void> pickRegion() => RegionPickerSheet.show();

  void _listenUpcoming(String uid) {
    _upcomingSub = FirebaseFirestore.instance
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
      if (Get.isDialogOpen == true || Get.isBottomSheetOpen == true) return;
      box.write('last', DateTime.now().millisecondsSinceEpoch);
      final vet = (d['vetName'] as String?)?.trim() ?? '';
      final go = await Get.bottomSheet<bool>(
        VvSheet(
          title: 'Como foi o atendimento?',
          subtitle: vet.isEmpty
              ? 'Sua avaliação leva menos de um minuto e ajuda outros tutores a escolher bem.'
              : 'Conte como foi a consulta com $vet. Sua avaliação leva menos de um minuto e ajuda outros tutores a escolher bem.',
          actions: [
            VvPillButton(
                label: 'Avaliar agora',
                onTap: () => Get.back(result: true)),
            VvPillButton(
                label: 'Agora não',
                kind: VvPillKind.outlined,
                onTap: () => Get.back(result: false)),
          ],
        ),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
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
    // Visitante que ainda não disse onde mora: pergunta antes de listar.
    if (index == 1 && isGuest && !Get.find<RegionService>().hasRegion) {
      RegionPickerSheet.show();
    }
  }

  void _listenNotifications(String uid) {
    final db = FirebaseFirestore.instance;
    db.collection('users').doc(uid).get().then((s) {
      final t = s.data()?['lastNotifSeenAt'];
      _lastNotifSeen = t is Timestamp ? t.toDate() : null;
      _recountUnread();
    }).catchError((_) {});
    _notifSub = db
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
