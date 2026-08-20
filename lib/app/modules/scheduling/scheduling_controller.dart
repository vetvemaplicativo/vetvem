import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/vet_model.dart';
import '../../services/notification_service.dart';
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

  final selectedPetIndex = Rx<int?>(null);
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

  void selectPet(int index) => selectedPetIndex.value = index;

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

  bool isTimeBooked(String time) => bookedTimes.contains(time);

  void selectTime(String time) {
    if (isTimeBooked(time)) {
      Get.snackbar(
        'Horário indisponível',
        'Este horário já está reservado. Escolha outro.',
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
    final i = selectedPetIndex.value;
    if (i == null || i >= pets.length) return '';
    return pets[i].name;
  }

  Future<void> confirmScheduling() async {
    if (selectedPetIndex.value == null) {
      Get.snackbar('Atenção', 'Selecione um pet',
          snackPosition: SnackPosition.TOP);
      return;
    }
    if (selectedService.value == null) {
      Get.snackbar('Atenção', 'Selecione um serviço',
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
    final petIndex = selectedPetIndex.value!;
    final pet = profile.pets[petIndex];

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
        'value': service.price.toStringAsFixed(2).replaceAll('.', ','),
        'paymentStatus': 'pending_payment',
        'status': 'pending_confirmation',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Notifica o vet sobre novo agendamento
      if (vet?.id != null && vet!.id.isNotEmpty) {
        await NotificationService.sendTo(
          toUid: vet.id,
          title: '🗓️ Novo agendamento!',
          body: '${profile.userName.value} agendou ${service.name} para ${pet.name} em $formattedDate às ${selectedTime.value}.',
          tipo: 'novo_agendamento',
          appointmentId: ref.id,
        );
      }

      isConfirmed.value = true;
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
