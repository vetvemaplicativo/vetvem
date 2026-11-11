import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/service_area_model.dart';
import '../../data/models/vet_model.dart';
import '../../utils/brazilian_states.dart';
import '../../routes/app_routes.dart';
import '../../services/public_reads_service.dart';
import '../../services/taxonomy_service.dart';

class VetsController extends GetxController {
  final searchController = TextEditingController();
  final allVets = <VetModel>[].obs;
  final filteredVets = <VetModel>[].obs;
  final selectedSpecialty = ''.obs;
  final selectedVet = Rx<VetModel?>(null);
  final isLoading = true.obs;

  final vetReviews = <Map<String, dynamic>>[].obs;
  final isLoadingReviews = false.obs;

  // 0 = Relevância, 1 = Melhor avaliados, 2 = Mais atendimentos, 3 = Menor preço
  final sortIndex = 0.obs;

  // ── Filtro por endereço do tutor ─────────────────────────────────
  final filterByArea = false.obs;
  // "Ver veterinários de outras cidades": ignora a restrição de cidade.
  final showOtherCities = false.obs;
  String get tutorUf => _tutorUf;
  String get tutorCity => _tutorCity;
  final tutorAddressLabel = ''.obs; // ex.: "Icaraí, Niterói"
  String _tutorUf = '';
  String _tutorCity = '';
  String _tutorBairro = '';

  // Vem do TaxonomyService (config/specialties no Firestore, editável pelo
  // painel admin) — 'Todos' sempre na frente para o filtro "sem seleção".
  List<String> get specialties =>
      ['Todos', ...Get.find<TaxonomyService>().specialtyValues];

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args != null && args['category'] != null) {
      final cat = args['category'] as String;
      if (cat == 'Consulta') { selectedSpecialty.value = 'Clínica Geral'; }
      else { selectedSpecialty.value = cat; }
    }
    searchController.addListener(_filter);
    _loadTutorAddress();
    _loadVets();
  }

  Future<void> _loadTutorAddress() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final addrs =
          List<Map<String, dynamic>>.from(doc.data()?['addresses'] ?? []);
      if (addrs.isEmpty) return;
      final a = addrs.first;
      _tutorUf = _toUfSigla((a['state'] ?? '').toString());
      _tutorCity = (a['city'] ?? '').toString().trim();
      _tutorBairro = (a['neighborhood'] ?? '').toString().trim();
      if (_tutorCity.isNotEmpty) {
        tutorAddressLabel.value =
            _tutorBairro.isNotEmpty ? '$_tutorBairro, $_tutorCity' : _tutorCity;
        // Filtro por região ligado por padrão quando há endereço cadastrado —
        // atendimento é a domicílio, não faz sentido listar por padrão
        // profissionais de outro estado/cidade. O tutor ainda pode desligar
        // manualmente (toggleAreaFilter) se quiser ver todo mundo.
        filterByArea.value = true;
        _filter();
      }
    } catch (_) {
      // Sem endereço: o filtro simplesmente fica indisponível.
    }
  }

  /// Aceita sigla ("RJ") ou nome completo ("Rio de Janeiro") — endereços
  /// antigos podem ter sido salvos com o nome por extenso.
  String _toUfSigla(String state) {
    final s = state.trim();
    if (s.length == 2) return s.toUpperCase();
    final norm = normalizeSearchText(s);
    for (final st in brazilianStates) {
      if (normalizeSearchText(st.nome) == norm) return st.sigla;
    }
    return s.toUpperCase();
  }

  void showAllCities() {
    showOtherCities.value = true;
    _filter();
    update();
  }

  void toggleAreaFilter() {
    if (tutorAddressLabel.value.isEmpty) {
      Get.snackbar(
        'Cadastre um endereço',
        'Adicione um endereço no seu perfil para ver só '
            'quem atende na sua região.',
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return;
    }
    showOtherCities.value = false;
    filterByArea.toggle();
    _filter();
    update();
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _vetsSub;

  // Escuta ao vivo (não .get() único): mudanças como o profissional pausar
  // o recebimento de pedidos (isAvailable) precisam refletir na busca do
  // tutor sem exigir reabrir o app.
  //
  // Lê a vitrine pública (professionals_public), NÃO users/{uid}: o perfil
  // completo tem telefone, e-mail, endereço e PIX e não é legível por terceiros.
  // A vitrine é mantida pela Cloud Function mirrorProfessionalPublic e só
  // contém profissionais aprovados e não bloqueados.
  void _loadVets() {
    isLoading.value = true;
    _vetsSub?.cancel();
    _vetsSub = FirebaseFirestore.instance
        .collection('professionals_public')
        .snapshots()
        .listen(_onVetsSnapshot, onError: (_) {
      allVets.assignAll([]);
      isLoading.value = false;
      _filter();
    });
  }

  Future<void> _onVetsSnapshot(QuerySnapshot<Map<String, dynamic>> snap) async {
    try {
      // A nota e a contagem vêm da vitrine (professionals_public), mantidas pelo
      // servidor — o app não baixa mais os agendamentos de todo mundo.
      // professionals_public só contém profissionais aprovados e não bloqueados
      // (a function remove o doc quando deixam de ser) — não há o que filtrar.
      final firestoreVets = snap.docs.map((doc) {
        final d = doc.data();
        final cats = List<String>.from(d['categories'] ?? []);
        final srvData = List<Map<String, dynamic>>.from(d['services'] ?? []);
        final services = srvData.map((s) {
          final price = double.tryParse(
              s['price']?.toString().replaceAll(',', '.') ?? '0') ?? 0;
          final addRaw = s['additionalPrice']?.toString().replaceAll(',', '.') ?? '';
          return VetService(
            name: s['name'] ?? '',
            description: '',
            price: price,
            unit: s['unit'] ?? 'consulta',
            perAnimal: s['perAnimal'] == true,
            additionalPrice: addRaw.trim().isEmpty ? null : double.tryParse(addRaw),
            travelFee: double.tryParse(
                (s['travelFee']?.toString() ?? '').replaceAll(',', '.')),
            travelByKm: s['travelByKm'] == true,
            instructions: (s['instructions']?.toString() ?? '').trim(),
          );
        }).toList();

        final vetName = d['name'] as String? ?? '';
        final reviewCount = (d['reviewCount'] as num?)?.toInt() ?? 0;
        final rating = (d['rating'] as num?)?.toDouble() ?? 0.0;
        final completedCount = (d['completedCount'] as num?)?.toInt() ?? 0;

        // Bairros para exibição a partir da área de atuação do profissional
        // (cidade inteira aparece pelo nome da cidade)
        final area = AreaAtuacao.fromMap(
            (d['area_atuacao'] as Map?)?.cast<String, dynamic>());
        final neighborhoods = <String>[
          for (final c in area.cidades)
            if (c.atendeCidadeToda) c.nome else ...c.bairros,
        ];

        return VetModel(
          id: doc.id,
          name: vetName,
          crmv: d['crmv'] ?? '',
          specialty: cats.isNotEmpty ? cats.first : 'Clínica Geral',
          specialtyTags: cats,
          rating: rating,
          reviewCount: reviewCount,
          completedCount: completedCount,
          pricePerVisit: services.isNotEmpty ? services.first.price : 0,
          imageUrl: d['photoUrl'] ?? '',
          photoBase64: d['photoBase64'] ?? '',
          bio: d['bio'] ?? '',
          availableDays: List<String>.from(d['availableDays'] ?? []),
          availableTimes: List<String>.from(d['availableTimes'] ?? []),
          distanceKm: 0.0,
          isAvailable: d['isAvailable'] != false,
          neighborhoods: neighborhoods,
          services: services,
          animalSpecies: List<String>.from(d['animalSpecies'] ?? []),
          areaAtuacao: area.isEmpty ? null : area,
          travelModel: d['travelModel'] == 'per_km' ? 'per_km' : 'fixed',
          travelPerKm: (d['travelPerKm'] as num?)?.toDouble() ?? 0,
          travelRoundTrip: d['travelRoundTrip'] != false,
          travelMaxKm: (d['travelMaxKm'] as num?)?.toDouble() ?? 0,
        );
      }).toList();

      allVets.assignAll(firestoreVets);
    } catch (_) {
      allVets.assignAll([]);
    } finally {
      isLoading.value = false;
      _filter();
    }
  }

  void selectSpecialty(String specialty) {
    selectedSpecialty.value = specialty == 'Todos' ? '' : specialty;
    _filter();
    update();
  }


  void setSort(int index) {
    sortIndex.value = index;
    _filter();
    update();
  }

  void _filter() {
    final query = searchController.text.toLowerCase();
    final specialty = selectedSpecialty.value;
    var result = allVets.where((v) {
      final matchesSearch = query.isEmpty ||
          v.name.toLowerCase().contains(query) ||
          v.specialty.toLowerCase().contains(query);
      final matchesSpecialty = specialty.isEmpty ||
          v.specialty == specialty ||
          v.specialtyTags.contains(specialty);
      // Filtro por área: com o toggle ligado, exige bater o bairro exato do
      // tutor. Desligado, continua restrito à cidade do tutor (nunca mostra
      // o Brasil inteiro) — só mostra todo mundo se o tutor não tiver
      // nenhum endereço cadastrado, caso em que não há cidade pra restringir.
      final matchesArea = showOtherCities.value ||
          (filterByArea.value
          ? (v.areaAtuacao?.cobreEndereco(
                uf: _tutorUf,
                cidade: _tutorCity,
                bairro: _tutorBairro,
              ) ??
              false)
          : (_tutorCity.isEmpty ||
              (v.areaAtuacao?.cobreEndereco(
                    uf: _tutorUf,
                    cidade: _tutorCity,
                  ) ??
                  false)));
      return matchesSearch && matchesSpecialty && matchesArea;
    }).toList();

    switch (sortIndex.value) {
      case 0: // Relevância — score composto
        result.sort((a, b) => b.rankScore.compareTo(a.rankScore));
      case 1: // Melhor avaliados
        result.sort((a, b) => b.rating.compareTo(a.rating));
      case 2: // Mais atendimentos
        result.sort((a, b) => b.completedCount.compareTo(a.completedCount));
      case 3: // Menor preço
        result.sort((a, b) => a.startingPrice.compareTo(b.startingPrice));
    }

    filteredVets.assignAll(result);
  }

  void reloadVets() => _loadVets();

  void openVetDetail(VetModel vet) {
    selectedVet.value = vet;
    _loadReviews(vet.id);
    Get.toNamed(Routes.vetDetail)?.then((_) {
      // Ao voltar do detalhe, força rebuild da lista
      filteredVets.refresh();
    });
  }

  Future<void> _loadReviews(String vetId) async {
    isLoadingReviews.value = true;
    vetReviews.clear();
    try {
      final vet = selectedVet.value;
      final vetName = vet?.name ?? '';

      // Pelo servidor: avaliações já filtradas (primeiro nome do tutor) e média.
      final r = await PublicReadsService.vetReviews(vetId: vetId, vetName: vetName);
      final reviewed = (r['reviews'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      vetReviews.assignAll(reviewed);

      // Mantém em memória a nota/contagem coerentes com as avaliações exibidas.
      if (reviewed.isNotEmpty) {
        final count = (r['reviewCount'] as num?)?.toInt() ?? reviewed.length;
        final avgRounded = (r['rating'] as num?)?.toDouble() ?? 0.0;
        final vet = selectedVet.value;
        if (vet != null &&
            (vet.rating != avgRounded || vet.reviewCount != count)) {
          final idx = allVets.indexWhere((v) => v.id == vetId);
          if (idx >= 0) {
            final updated = VetModel(
              id: vet.id,
              name: vet.name,
              specialty: vet.specialty,
              specialtyTags: vet.specialtyTags,
              rating: avgRounded,
              reviewCount: count,
              completedCount: vet.completedCount,
              cancellationRate: vet.cancellationRate,
              crmv: vet.crmv,
              bio: vet.bio,
              neighborhoods: vet.neighborhoods,
              availableDays: vet.availableDays,
              availableTimes: vet.availableTimes,
              isAvailable: vet.isAvailable,
              pricePerVisit: vet.pricePerVisit,
              imageUrl: vet.imageUrl,
              photoBase64: vet.photoBase64,
              distanceKm: vet.distanceKm,
              services: vet.services,
              animalSpecies: vet.animalSpecies,
              areaAtuacao: vet.areaAtuacao,
              travelModel: vet.travelModel,
              travelPerKm: vet.travelPerKm,
              travelRoundTrip: vet.travelRoundTrip,
              travelMaxKm: vet.travelMaxKm,
            );
            allVets.removeAt(idx);
            allVets.insert(idx, updated);
            selectedVet.value = updated;
            _filter();
          }
        }
      }
    } catch (_) {
      vetReviews.clear();
    } finally {
      isLoadingReviews.value = false;
    }
  }

  void scheduleVet(VetModel vet) {
    selectedVet.value = vet;
    Get.toNamed(Routes.scheduling);
  }

  @override
  void onClose() {
    _vetsSub?.cancel();
    searchController.dispose();
    super.onClose();
  }
}
