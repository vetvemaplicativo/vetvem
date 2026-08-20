import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../routes/app_routes.dart';
import '../vets/vets_controller.dart';

class PetProfile {
  final String name;
  final String species; // 'dog' | 'cat' | 'other'
  final String breed;
  final String age; // mantido para compatibilidade com dados antigos
  final int? birthYear;
  final int? birthMonth;
  final String sex; // 'Macho' | 'Fêmea'
  final bool castrated;
  final String photoBase64;

  const PetProfile({
    required this.name,
    required this.species,
    required this.breed,
    this.age = '',
    this.birthYear,
    this.birthMonth,
    required this.sex,
    required this.castrated,
    this.photoBase64 = '',
  });

  // Calcula a idade formatada automaticamente baseada em birthYear/birthMonth
  String get ageLabel {
    if (birthYear == null || birthMonth == null) {
      return age.isNotEmpty ? age : '';
    }
    final now = DateTime.now();
    int months = (now.year - birthYear!) * 12 + (now.month - birthMonth!);
    if (months < 0) months = 0;
    final years = months ~/ 12;
    final remainingMonths = months % 12;
    if (years == 0) {
      return '$remainingMonths ${remainingMonths == 1 ? 'mês' : 'meses'}';
    } else if (remainingMonths == 0) {
      return '$years ${years == 1 ? 'ano' : 'anos'}';
    } else {
      return '$years ${years == 1 ? 'ano' : 'anos'} e $remainingMonths ${remainingMonths == 1 ? 'mês' : 'meses'}';
    }
  }
}

class ConsultationHistory {
  final String id;
  final String vetName;
  final String specialty;
  final String date;
  final String time;
  final String period;
  // 'pending_payment' | 'pending_confirmation' | 'confirmed' | 'completed' | 'cancelled' | 'rejected'
  final String status;
  final String petName;
  final String serviceName;
  final String value;
  final String? vetPhone;
  final String paymentMethod;
  final int? rating;
  final String? comment;
  final bool sentToClient;
  final Map<String, dynamic>? prontuario;
  final String vetCrmv;
  final String petPhotoBase64;
  final String paymentStatus;

  const ConsultationHistory({
    required this.id,
    required this.vetName,
    required this.specialty,
    required this.date,
    this.time = '',
    required this.period,
    required this.status,
    this.petName = '',
    this.serviceName = '',
    this.value = '',
    this.vetPhone,
    this.paymentMethod = 'pix',
    this.rating,
    this.comment,
    this.sentToClient = false,
    this.prontuario,
    this.vetCrmv = '',
    this.petPhotoBase64 = '',
    this.paymentStatus = '',
  });

  bool get canRate => status == 'completed' && rating == null;
  bool get isActive => status == 'pending_confirmation' || status == 'confirmed';
}

class SavedAddress {
  final String label; // 'Casa', 'Trabalho', 'Outro'
  final String street;
  final String number;
  final String complement;
  final String neighborhood;
  final String city;
  final String state;
  final String cep;

  const SavedAddress({
    required this.label,
    required this.street,
    required this.number,
    required this.complement,
    required this.neighborhood,
    required this.city,
    required this.state,
    required this.cep,
  });

  String get fullLine => '$street, $number${complement.isNotEmpty ? ' – $complement' : ''} · $neighborhood, $city/$state';
}

class SavedCard {
  final String holderName;
  final String lastFour;
  final String expiry;
  final String brand; // 'Visa', 'Mastercard', etc.
  // Referências ao cofre do Mercado Pago (nunca guardamos o número completo).
  // Com elas, pagar de novo pede só o CVV.
  final String mpCardId;
  final String paymentMethodId;

  const SavedCard({
    required this.holderName,
    required this.lastFour,
    required this.expiry,
    required this.brand,
    this.mpCardId = '',
    this.paymentMethodId = '',
  });

  bool get canQuickPay => mpCardId.isNotEmpty;
}

class ProfileController extends GetxController {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final userName = ''.obs;
  final userPhotoUrl = ''.obs;
  final userEmail = ''.obs;
  final userPhone = ''.obs;
  final isLoadingProfile = true.obs;
  final isUploadingPhoto = false.obs;

  final addresses = <SavedAddress>[].obs;
  final savedCards = <SavedCard>[].obs;
  final mpCustomerId = ''.obs; // customer no Mercado Pago (cofre de cartões)

  @override
  void onInit() {
    super.onInit();
    _loadProfile();
    _listenConsultations();
  }

  Future<void> _loadProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      userName.value = data['name'] ?? _auth.currentUser?.displayName ?? '';
      userPhotoUrl.value = data['photoBase64'] ?? data['photoUrl'] ?? _auth.currentUser?.photoURL ?? '';
      userEmail.value = data['email'] ?? _auth.currentUser?.email ?? '';
      userPhone.value = data['phone'] ?? '';

      // Carrega pets
      final petsData = List<Map<String, dynamic>>.from(data['pets'] ?? []);
      pets.value = petsData.map((p) => PetProfile(
        name: p['name'] ?? '',
        species: p['species'] ?? 'dog',
        breed: p['breed'] ?? '',
        age: p['age'] ?? '',
        birthYear: p['birthYear'] as int?,
        birthMonth: p['birthMonth'] as int?,
        sex: p['sex'] ?? 'Macho',
        castrated: p['castrated'] ?? false,
        photoBase64: p['photoBase64'] ?? '',
      )).toList();

      // Carrega endereços
      final addrsData = List<Map<String, dynamic>>.from(data['addresses'] ?? []);
      addresses.value = addrsData.map((a) => SavedAddress(
        label: a['label'] ?? 'Casa',
        street: a['street'] ?? '',
        number: a['number'] ?? '',
        complement: a['complement'] ?? '',
        neighborhood: a['neighborhood'] ?? '',
        city: a['city'] ?? '',
        state: a['state'] ?? '',
        cep: a['cep'] ?? '',
      )).toList();

      // Carrega cartões
      final cardsData = List<Map<String, dynamic>>.from(data['cards'] ?? []);
      savedCards.value = cardsData.map((c) => SavedCard(
        holderName: c['holderName'] ?? '',
        lastFour: c['lastFour'] ?? '',
        expiry: c['expiry'] ?? '',
        brand: c['brand'] ?? 'Crédito',
        mpCardId: c['mpCardId'] ?? '',
        paymentMethodId: c['paymentMethodId'] ?? '',
      )).toList();
      mpCustomerId.value = data['mpCustomerId'] ?? '';
    } catch (_) {
      userName.value = _auth.currentUser?.displayName ?? '';
      userEmail.value = _auth.currentUser?.email ?? '';
    } finally {
      isLoadingProfile.value = false;
    }
  }

  Future<void> pickAndUploadPhoto({bool camera = false}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 256,
      maxHeight: 256,
      imageQuality: 75,
    );
    if (picked == null) return;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    isUploadingPhoto.value = true;
    try {
      final bytes = await File(picked.path).readAsBytes();
      final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      await _firestore.collection('users').doc(uid).update({'photoBase64': base64Str});
      userPhotoUrl.value = base64Str;
      Get.snackbar('Foto atualizada', 'Sua foto de perfil foi salva.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xFF22C55E),
          colorText: const Color(0xFFFFFFFF),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 3));
    } catch (_) {
      Get.snackbar('Erro', 'Não foi possível salvar a foto.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xFFEF4444),
          colorText: const Color(0xFFFFFFFF),
          margin: const EdgeInsets.all(16),
          borderRadius: 12);
    } finally {
      isUploadingPhoto.value = false;
    }
  }

  Future<void> _savePets() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).update({
      'pets': pets.map((p) => {
        'name': p.name,
        'species': p.species,
        'breed': p.breed,
        'age': p.age,
        'birthYear': p.birthYear,
        'birthMonth': p.birthMonth,
        'sex': p.sex,
        'castrated': p.castrated,
        'photoBase64': p.photoBase64,
      }).toList(),
    });
  }

  Future<void> _saveAddresses() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).update({
      'addresses': addresses.map((a) => {
        'label': a.label,
        'street': a.street,
        'number': a.number,
        'complement': a.complement,
        'neighborhood': a.neighborhood,
        'city': a.city,
        'state': a.state,
        'cep': a.cep,
      }).toList(),
    });
  }

  Future<void> updateProfile({
    required String name,
    required String email,
    required String phone,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).update({
      'name': name,
      'email': email,
      'phone': phone,
    });
    if (name.isNotEmpty) await _auth.currentUser?.updateDisplayName(name);
    userName.value = name;
    userEmail.value = email;
    userPhone.value = phone;
  }

  void addAddress(SavedAddress address) {
    addresses.add(address);
    _saveAddresses();
  }

  void removeAddress(SavedAddress address) {
    addresses.remove(address);
    _saveAddresses();
  }

  static const maxCards = 5;

  bool addCard(SavedCard card) {
    // Já existe? Atualiza se a nova versão ganhou vínculo com o cofre MP
    final idx = savedCards.indexWhere(
        (c) => c.lastFour == card.lastFour && c.brand == card.brand);
    if (idx >= 0) {
      if (card.canQuickPay && !savedCards[idx].canQuickPay) {
        savedCards[idx] = card;
        _saveCards();
      }
      return true;
    }
    if (savedCards.length >= maxCards) {
      Get.snackbar('Limite de cartões',
          'Você pode salvar até $maxCards cartões. Exclua um para adicionar outro.',
          snackPosition: SnackPosition.TOP);
      return false;
    }
    savedCards.add(card);
    _saveCards();
    return true;
  }

  void removeCard(SavedCard card) {
    savedCards.remove(card);
    _saveCards();
  }

  Future<void> _saveCards() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).update({
      'cards': savedCards.map((c) => {
        'holderName': c.holderName,
        'lastFour': c.lastFour,
        'expiry': c.expiry,
        'brand': c.brand,
        'mpCardId': c.mpCardId,
        'paymentMethodId': c.paymentMethodId,
      }).toList(),
    });
  }

  static String detectBrand(String digits) {
    // Elo antes de Visa/Master: seus BINs começam com 4, 5 e 6
    if (RegExp(r'^(636368|438935|504175|451416|636297|5067|4576|4011|506699)').hasMatch(digits)) return 'Elo';
    if (digits.startsWith('4')) return 'Visa';
    if (RegExp(r'^5[1-5]').hasMatch(digits)) return 'Mastercard';
    if (RegExp(r'^2(2[2-9]|[3-6]|7[01])').hasMatch(digits)) return 'Mastercard'; // série 2221–2720
    if (RegExp(r'^3[47]').hasMatch(digits)) return 'Amex';
    if (RegExp(r'^(301|305|3095|36|38)').hasMatch(digits)) return 'Diners';
    if (digits.startsWith('6011') || digits.startsWith('65')) return 'Discover';
    if (digits.startsWith('384') || digits.startsWith('606282')) return 'Hipercard';
    return 'Crédito';
  }

  final pets = <PetProfile>[].obs;

  final recentConsultations = <ConsultationHistory>[].obs;

  // Filtro da aba consultas: 0=Todas 1=Agendadas 2=Concluídas 3=Canceladas
  final consultaFilter = 0.obs;

  List<ConsultationHistory> get filteredConsultations {
    switch (consultaFilter.value) {
      case 1:
        return recentConsultations
            .where((c) =>
                c.status == 'pending_confirmation' ||
                c.status == 'confirmed' ||
                c.status == 'pending_payment')
            .toList();
      case 2:
        return recentConsultations
            .where((c) => c.status == 'completed')
            .toList();
      case 3:
        return recentConsultations
            .where((c) => c.status == 'cancelled' || c.status == 'rejected')
            .toList();
      default:
        return recentConsultations.toList();
    }
  }

  void _listenConsultations() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _firestore
        .collection('appointments')
        .where('tutorId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      final docs = snap.docs.toList()
        ..sort((a, b) {
          final at = a.data()['createdAt'];
          final bt = b.data()['createdAt'];
          if (at == null || bt == null) return 0;
          return bt.compareTo(at);
        });
      recentConsultations.value = docs.map((doc) {
        final d = doc.data();
        final photo = d['petPhotoBase64'] ?? '';
        print('[listen] doc=${doc.id} pet=${d['petName']} photoLen=${photo.length}');
        return ConsultationHistory(
          id: doc.id,
          vetName: d['vetName'] ?? '',
          specialty: d['serviceName'] ?? '',
          date: d['date'] ?? '',
          time: d['time'] ?? '',
          period: '',
          status: d['status'] ?? 'pending_confirmation',
          petName: d['petName'] ?? '',
          serviceName: d['serviceName'] ?? '',
          value: d['value'] ?? '',
          paymentMethod: d['paymentMethod'] ?? 'pix',
          paymentStatus: d['paymentStatus'] ?? '',
          rating: d['rating'] as int?,
          comment: d['comment'] as String?,
          sentToClient: d['sentToClient'] == true,
          vetCrmv: d['vetCrmv'] ?? '',
          petPhotoBase64: photo,
          prontuario: d['prontuario'] != null
              ? {
                  ...(d['prontuario'] as Map<String, dynamic>),
                  'complementos':
                      List<Map<String, dynamic>>.from(d['complementos'] ?? []),
                }
              : null,
        );
      }).toList();
    });
  }

  Future<void> rateConsultation(String id, int rating, String comment) async {
    // Passo crítico — salva a avaliação no appointment
    await _firestore.collection('appointments').doc(id).update({
      'rating': rating,
      'comment': comment.trim().isEmpty ? null : comment.trim(),
    });

    // Atualiza agregado no profissional — falha silenciosamente para não bloquear o usuário
    _updateVetRatingAggregate(id).catchError((_) {});
  }

  Future<void> _updateVetRatingAggregate(String appointmentId) async {
    final appt = await _firestore.collection('appointments').doc(appointmentId).get();
    final apptData = appt.data() ?? {};
    final vetId = apptData['vetId'] as String?;
    final vetName = apptData['vetName'] as String?;
    if ((vetId == null || vetId.isEmpty) && (vetName == null || vetName.isEmpty)) return;

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = [];
    if (vetId != null && vetId.isNotEmpty) {
      final snap = await _firestore.collection('appointments')
          .where('vetId', isEqualTo: vetId).get();
      allDocs.addAll(snap.docs);
    }
    if (vetName != null && vetName.isNotEmpty) {
      final snap = await _firestore.collection('appointments')
          .where('vetName', isEqualTo: vetName).get();
      for (final doc in snap.docs) {
        if (!allDocs.any((d) => d.id == doc.id)) allDocs.add(doc);
      }
    }

    double ratingSum = 0;
    int ratingCount = 0;
    int completedCount = 0;
    for (final doc in allDocs) {
      final d = doc.data();
      if (d['status'] == 'completed') completedCount++;
      final r = d['rating'];
      if (r != null) {
        ratingSum += (r as num).toDouble();
        ratingCount++;
      }
    }
    final avgRating = ratingCount > 0
        ? double.parse((ratingSum / ratingCount).toStringAsFixed(1))
        : 0.0;

    String? targetVetId = (vetId != null && vetId.isNotEmpty) ? vetId : null;
    if (targetVetId == null && vetName != null && vetName.isNotEmpty) {
      final userSnap = await _firestore.collection('users')
          .where('name', isEqualTo: vetName).get();
      final match = userSnap.docs.where((d) => d.data()['role'] == 'professional');
      if (match.isNotEmpty) targetVetId = match.first.id;
    }
    if (targetVetId == null) return;

    await _firestore.collection('users').doc(targetVetId).update({
      'rating': avgRating,
      'reviewCount': ratingCount,
      'completedCount': completedCount,
    });

    try {
      Get.find<VetsController>().reloadVets();
    } catch (_) {}
  }

  Future<String> pickPetPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 256, maxHeight: 256, imageQuality: 75,
    );
    if (picked == null) return '';
    final bytes = await File(picked.path).readAsBytes();
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  void addPet(PetProfile pet) {
    pets.add(pet);
    _savePets();
  }

  void removePet(PetProfile pet) {
    pets.removeWhere((p) => p.name == pet.name && p.species == pet.species);
    _savePets();
  }

  void updatePet(PetProfile old, String name, String breed,
      {int? birthYear, int? birthMonth, String? photoBase64}) {
    final i = pets.indexWhere((p) => p.name == old.name && p.species == old.species);
    if (i == -1) return;
    final newName = name.isEmpty ? old.name : name;
    final newPhoto = photoBase64 ?? old.photoBase64;
    pets[i] = PetProfile(
      name: newName,
      species: old.species,
      breed: breed.isEmpty ? old.breed : breed,
      age: old.age,
      birthYear: birthYear ?? old.birthYear,
      birthMonth: birthMonth ?? old.birthMonth,
      sex: old.sex,
      castrated: old.castrated,
      photoBase64: newPhoto,
    );
    pets.refresh();
    _savePets();
    if (newPhoto.isNotEmpty) {
      _backfillPetPhotoInAppointments(old.name, newName, newPhoto);
    }
  }

  Future<void> _backfillPetPhotoInAppointments(
      String oldName, String newName, String photoBase64) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    print('[backfill] searching appointments for tutorId=$uid petName="$oldName"/"$newName"');
    final snap = await _firestore
        .collection('appointments')
        .where('tutorId', isEqualTo: uid)
        .get();
    print('[backfill] found ${snap.docs.length} appointments');
    final batch = _firestore.batch();
    int count = 0;
    for (final doc in snap.docs) {
      final petName = doc.data()['petName'] as String? ?? '';
      print('[backfill] appointment petName="$petName"');
      if (petName.trim().toLowerCase() == oldName.trim().toLowerCase() ||
          petName.trim().toLowerCase() == newName.trim().toLowerCase()) {
        batch.update(doc.reference, {'petPhotoBase64': photoBase64});
        count++;
      }
    }
    print('[backfill] updating $count appointments');
    await batch.commit();
    print('[backfill] done');
  }

  Future<void> logout() async {
    await _auth.signOut();
    Get.delete<ProfileController>(force: true);
    Get.offAllNamed(Routes.login);
  }
}
