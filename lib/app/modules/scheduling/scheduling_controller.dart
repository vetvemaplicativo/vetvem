import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/vet_model.dart';
import '../../routes/app_routes.dart';
import '../../services/analytics_service.dart';
import '../profile/profile_controller.dart';
import '../vets/vets_controller.dart';

class SchedulePeriod {
  final String label;
  final String hours;
  final IconData icon;
  const SchedulePeriod(this.label, this.hours, this.icon);
}

class PetOption {
  final String name;
  final String species; // 'dog' | 'cat' | 'other'
  PetOption({required this.name, required this.species});
}

class SchedulingController extends GetxController {
  final notesController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  List<PetOption> get pets {
    final profile = Get.find<ProfileController>();
    return profile.pets.map((p) => PetOption(name: p.name, species: p.species)).toList();
  }

  // ── Vários animais no mesmo pedido (qualquer serviço) ──────────────
  static const maxAnimalsBeforeQuote = 10; // acima disso só avisamos e oferecemos orçamento
  final selectedPetIndexes = RxSet<int>({}); // pets do perfil marcados
  final extraAnimals = 0.obs; // animais SEM cadastro (só quantidade)
  final petFilter = 'all'.obs; // all | cat | dog

  /// Nº de animais do pedido (mínimo 1).
  int get animalCount {
    final n = selectedPetIndexes.length + extraAnimals.value;
    return n < 1 ? 1 : n;
  }

  /// Total do pedido para o serviço escolhido.
  double get totalPrice {
    final s = selectedService.value;
    if (s == null) return 0;
    return s.totalFor(animalCount);
  }

  void togglePet(int i) {
    if (selectedPetIndexes.contains(i)) {
      selectedPetIndexes.remove(i);
    } else {
      selectedPetIndexes.add(i);
    }
  }

  /// Marca todos os pets do filtro atual (ou desmarca se já estiverem todos).
  void toggleAllFiltered() {
    final profile = Get.find<ProfileController>();
    final idx = <int>[
      for (var i = 0; i < profile.pets.length; i++)
        if (petFilter.value == 'all' || profile.pets[i].species == petFilter.value) i
    ];
    final allSelected = idx.isNotEmpty && idx.every(selectedPetIndexes.contains);
    if (allSelected) {
      selectedPetIndexes.removeAll(idx);
    } else {
      selectedPetIndexes.addAll(idx);
    }
  }

  void setExtraAnimals(int n) => extraAnimals.value = n.clamp(0, 50);
  final selectedService = Rx<VetService?>(null);
  final selectedDate = Rx<DateTime?>(null);
  final selectedTime = Rx<String?>(null);
  final selectedAddress = Rx<SavedAddress?>(null);
  final isLoading = false.obs;
  final isConfirmed = false.obs;
  final bookedTimes = RxSet<String>({}); // horários já ocupados na data selecionada

  @override
  void onInit() {
    super.onInit();
    Get.find<AnalyticsService>()
        .logBookingStarted(Get.find<VetsController>().selectedVet.value?.id ?? '');
    // Pré-seleciona o primeiro endereço salvo se houver
    final profile = Get.find<ProfileController>();
    if (profile.addresses.isNotEmpty) {
      selectedAddress.value = profile.addresses.first;
    }
  }

  void selectAddress(SavedAddress addr) => selectedAddress.value = addr;

  // Dias da semana no formato salvo pelo app Pro (weekday 1=Seg … 7=Dom)
  static const _dayLabels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab', 'Dom'];

  bool isDayAvailable(DateTime date) {
    final vet = Get.find<VetsController>().selectedVet.value;
    final days = vet?.availableDays ?? [];
    if (days.isEmpty) return true; // vet sem configuração: não bloqueia
    return days.contains(_dayLabels[date.weekday - 1]);
  }

  // Primeira data selecionável a partir de amanhã (evita initialDate inválido)
  DateTime get firstSelectableDate {
    var d = DateTime.now().add(const Duration(days: 1));
    for (var i = 0; i < 60; i++) {
      if (isDayAvailable(d)) return d;
      d = d.add(const Duration(days: 1));
    }
    return DateTime.now().add(const Duration(days: 1));
  }

  void selectService(VetService service) {
    selectedService.value = service;
  }

  // Horários agrupados por período — vêm do vet selecionado
  Map<String, List<String>> get timesByPeriod {
    final vet = Get.find<VetsController>().selectedVet.value;
    final times = vet?.availableTimes ?? [];
    final Map<String, List<String>> groups = {
      'Manhã': [],
      'Tarde': [],
      'Noite': [],
    };
    for (final t in times) {
      final hour = int.tryParse(t.split(':').first) ?? 0;
      if (hour < 12) {
        groups['Manhã']!.add(t);
      } else if (hour < 18) {
        groups['Tarde']!.add(t);
      } else {
        groups['Noite']!.add(t);
      }
    }
    // remove períodos sem horários
    groups.removeWhere((_, v) => v.isEmpty);
    return groups;
  }

  final expandedPeriod = Rx<String?>('Manhã'); // abre o primeiro por padrão

  void selectDate(DateTime date) {
    selectedDate.value = date;
    selectedTime.value = null; // limpa horário ao trocar data
    _loadBookedTimes();
  }

  Future<void> _loadBookedTimes() async {
    final vet = Get.find<VetsController>().selectedVet.value;
    if (vet == null || selectedDate.value == null) return;
    final dateStr = formattedDate;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('appointments')
          .where('vetName', isEqualTo: vet.name)
          .get();
      final occupied = snap.docs
          .where((doc) {
            final d = doc.data();
            final status = d['status'] as String? ?? '';
            return d['date'] == dateStr &&
                (status == 'confirmed' || status == 'pending_confirmation');
          })
          .map((doc) => doc.data()['time'] as String? ?? '')
          .where((t) => t.isNotEmpty)
          .toSet();
      bookedTimes.assignAll(occupied);
    } catch (_) {
      bookedTimes.clear();
    }
  }

  // Evita marcar um horário que já passou (ou está a poucos minutos) no dia
  // de hoje — sem essa checagem dava pra criar um agendamento cuja "hora da
  // consulta" já tinha chegado antes até do profissional ver a solicitação,
  // fazendo o timeout automático (expireUnanswered) cancelar em minutos.
  bool _isPastOrTooSoon(String time) {
    final date = selectedDate.value;
    if (date == null) return false;
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    if (!isToday) return false;
    final parts = time.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    final slot = DateTime(date.year, date.month, date.day, h, m);
    // Buffer de 2h: tempo mínimo de antecedência pra dar folga real pro
    // profissional confirmar (ele tem até 1h pra responder — ver
    // RESPONSE_DEADLINE_MINUTES em functions/index.js) e se preparar/deslocar.
    return slot.isBefore(now.add(const Duration(hours: 2)));
  }

  bool isTimeBooked(String time) => bookedTimes.contains(time) || _isPastOrTooSoon(time);

  void selectTime(String time) {
    if (bookedTimes.contains(time)) {
      Get.snackbar(
        'Horário indisponível',
        'Este horário já está reservado. Escolha outro.',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }
    if (_isPastOrTooSoon(time)) {
      Get.snackbar(
        'Horário indisponível',
        'Esse horário é muito próximo ou já passou. Escolha outro.',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }
    selectedTime.value = time;
  }
  void togglePeriod(String period) {
    expandedPeriod.value = expandedPeriod.value == period ? null : period;
  }

  String get formattedDate {
    if (selectedDate.value == null) return 'Selecione uma data';
    final d = selectedDate.value!;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String get selectedPetName {
    if (selectedPetIndexes.isEmpty) return '';
    final i = (selectedPetIndexes.toList()..sort()).first;
    if (i >= pets.length) return '';
    return pets[i].name;
  }

  Future<void> confirmScheduling() async {
    if (selectedService.value == null) {
      Get.snackbar('Atenção', 'Selecione um serviço',
          snackPosition: SnackPosition.TOP);
      return;
    }
    // Exige ao menos um animal CADASTRADO (o veterinário precisa de nome,
    // espécie e idade). Animais sem cadastro só se somam aos marcados.
    if (selectedPetIndexes.isEmpty) {
      Get.snackbar(
          'Atenção',
          Get.find<ProfileController>().pets.isEmpty
              ? 'Cadastre ao menos um animal no seu Perfil para agendar'
              : 'Selecione ao menos um animal',
          snackPosition: SnackPosition.TOP);
      return;
    }
    if (selectedDate.value == null) {
      Get.snackbar('Atenção', 'Selecione uma data',
          snackPosition: SnackPosition.TOP);
      return;
    }
    if (selectedTime.value == null) {
      Get.snackbar('Atenção', 'Selecione um horário',
          snackPosition: SnackPosition.TOP);
      return;
    }
    if (selectedAddress.value == null) {
      Get.snackbar('Atenção', 'Selecione o endereço para atendimento',
          snackPosition: SnackPosition.TOP);
      return;
    }

    final vet = Get.find<VetsController>().selectedVet.value;
    final profile = Get.find<ProfileController>();
    final service = selectedService.value!;
    final addr = selectedAddress.value!;
    // Pets do pedido: 1 ou vários. petCount/pets só vão no documento quando há
    // mais de um animal (ou serviço "por animal") — com 1 animal em serviço
    // comum o documento fica idêntico ao das versões anteriores.
    final chosen =
        (selectedPetIndexes.toList()..sort()).map((i) => profile.pets[i]).toList();
    final count = animalCount;
    final multi = service.perAnimal || count > 1;
    final total = service.totalFor(count);
    final pet = chosen.first; // validado acima: há ao menos um animal cadastrado

    isLoading.value = true;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final ref = FirebaseFirestore.instance.collection('appointments').doc();
      await ref.set({
        'tutorId': uid,
        'vetId': vet?.id ?? '',
        'tutorName': profile.userName.value,
        'vetName': vet?.name ?? 'Veterinário',
        'petName': pet.name,
        'petSpecies': pet.species,
        'petBreed': pet.breed,
        'petSex': pet.sex,
        'petAge': pet.ageLabel.isNotEmpty ? pet.ageLabel : pet.age,
        'petCastrated': pet.castrated,
        'petPhotoBase64': pet.photoBase64,
        'serviceName': service.name,
        'date': formattedDate,
        'time': selectedTime.value ?? '',
        'address': addr.fullLine,
        'value': total.toStringAsFixed(2).replaceAll('.', ','),
        if (multi) ...{
          'petCount': count,
          'pets': [
            for (final p in chosen)
              {
                'name': p.name,
                'species': p.species,
                'breed': p.breed,
                'sex': p.sex,
                'age': p.ageLabel.isNotEmpty ? p.ageLabel : p.age,
                'castrated': p.castrated,
              }
          ],
        },
        'paymentStatus': 'pending_payment',
        'status': 'pending_confirmation',
        'createdAt': FieldValue.serverTimestamp(),
      });

      Get.find<AnalyticsService>().logAppointmentCreated(
        vetId: vet?.id ?? '',
        serviceName: service.name,
      );

      // Fluxo atual: paga já ao solicitar (como Uber/iFood), em vez de
      // esperar o profissional confirmar pra só então cobrar — elimina o
      // "bate e volta" de notificações. O vet só é avisado depois do
      // pagamento aprovado (ver PaymentController._notifyVet). Se ele
      // recusar ou não responder, o valor é estornado automaticamente
      // (handleRejectedPayment, na Cloud Function appointmentHistorian).
      Get.toNamed(Routes.payment, arguments: {
        'appointmentId': ref.id,
        'vetId': vet?.id ?? '',
        'vetName': vet?.name ?? 'Veterinário',
        'tutorName': profile.userName.value,
        'petName': pet.name,
        'petSpecies': pet.species,
        'petBreed': pet.breed,
        'petSex': pet.sex,
        'petAge': pet.ageLabel.isNotEmpty ? pet.ageLabel : pet.age,
        'petCastrated': pet.castrated,
        'petPhotoBase64': pet.photoBase64,
        'serviceName': service.name,
        'date': formattedDate,
        'time': selectedTime.value ?? '',
        'address': addr.fullLine,
        'price': total,
        if (multi) 'petCount': count,
      });
    } catch (_) {
      Get.snackbar('Erro', 'Não foi possível realizar o agendamento. Tente novamente.',
          snackPosition: SnackPosition.TOP);
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    notesController.dispose();
    super.onClose();
  }
}
