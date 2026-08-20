import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/service_area_model.dart';
import '../../data/models/vet_model.dart';
import '../../utils/brazilian_states.dart';
import '../../routes/app_routes.dart';
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
    filterByArea.toggle();
    _filter();
    update();
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _vetsSub;

  // Escuta ao vivo (não .get() único): mudanças como o profissional pausar
  // o recebimento de pedidos (isAvailable) precisam refletir na busca do
  // tutor sem exigir reabrir o app.
  void _loadVets() {
    isLoading.value = true;
    _vetsSub?.cancel();
    _vetsSub = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'professional')
        .snapshots()
        .listen(_onVetsSnapshot, onError: (_) {
      allVets.assignAll([]);
      isLoading.value = false;
      _filter();
    });
  }

  Future<void> _onVetsSnapshot(QuerySnapshot<Map<String, dynamic>> snap) async {
    try {
      // Busca todos os appointments com status completed para calcular ratings
      final apptSnap = await FirebaseFirestore.instance
          .collection('appointments')
          .where('status', isEqualTo: 'completed')
          .get();

      // Agrupa ratings por vetId e vetName
      final Map<String, List<int>> ratingsByVetId = {};
      final Map<String, List<int>> ratingsByVetName = {};
      for (final doc in apptSnap.docs) {
        final d = doc.data();
        final r = (d['rating'] as num?)?.toInt() ?? 0;
        if (r <= 0) continue;
        final vid = d['vetId'] as String?;
        final vname = d['vetName'] as String?;
        if (vid != null && vid.isNotEmpty) {
          ratingsByVetId.putIfAbsent(vid, () => []).add(r);
        }
        if (vname != null && vname.isNotEmpty) {
          ratingsByVetName.putIfAbsent(vname, () => []).add(r);
        }
      }

      // Só profissionais aprovados no painel admin e não bloqueados
      // ('active' = contas antigas, anteriores ao fluxo de aprovação)
      final visibleDocs = snap.docs.where((doc) {
        final d = doc.data();
        final status = d['accountStatus'] ?? '';
        return (status == 'approved' || status == 'active') &&
            d['blocked'] != true;
      }).toList();

      final firestoreVets = visibleDocs.map((doc) {
        final d = doc.data();
        final cats = List<String>.from(d['categories'] ?? []);
        final srvData = List<Map<String, dynamic>>.from(d['services'] ?? []);
        final services = srvData.map((s) {
          final price = double.tryParse(
              s['price']?.toString().replaceAll(',', '.') ?? '0') ?? 0;
          return VetService(
            name: s['name'] ?? '',
            description: '',
            price: price,
            unit: s['unit'] ?? 'consulta',
          );
        }).toList();

        // Calcula rating a partir dos appointments (fonte verdadeira)
        final vetName = d['name'] as String? ?? '';
        final byId = ratingsByVetId[doc.id] ?? [];
        final byName = ratingsByVetName[vetName] ?? [];
        // Se byId não está vazio, usa só byId para evitar duplicatas de outros vets com mesmo nome
        final ratings = byId.isNotEmpty
            ? byId
            : byName;
        final reviewCount = ratings.length;
        final rating = reviewCount > 0
            ? double.parse(
                (ratings.reduce((a, b) => a + b) / reviewCount)
                    .toStringAsFixed(1))
            : 0.0;
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
      // Filtro por área: profissional sem área cadastrada fica de fora
      // quando o filtro está ativo.
      final matchesArea = !filterByArea.value ||
          (v.areaAtuacao?.cobreEndereco(
                uf: _tutorUf,
                cidade: _tutorCity,
                bairro: _tutorBairro,
              ) ??
              false);
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

      final List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = [];

      final byId = await FirebaseFirestore.instance
          .collection('appointments')
          .where('vetId', isEqualTo: vetId)
          .get();
      allDocs.addAll(byId.docs);

      if (vetName.isNotEmpty) {
        final byName = await FirebaseFirestore.instance
            .collection('appointments')
            .where('vetName', isEqualTo: vetName)
            .get();
        for (final doc in byName.docs) {
          if (!allDocs.any((d) => d.id == doc.id)) allDocs.add(doc);
        }
      }

      final reviewed = allDocs
          .where((d) {
            final r = d.data()['rating'];
            return r != null && (r as num) > 0;
          })
          .map((d) => {
                'rating': (d.data()['rating'] as num).toInt(),
                'comment': d.data()['comment'] ?? '',
                'tutorName': d.data()['tutorName'] ?? 'Anônimo',
                'petName': d.data()['petName'] ?? '',
                'date': d.data()['date'] ?? '',
              })
          .toList();

      reviewed.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
      vetReviews.assignAll(reviewed);

      // Corrige o documento do profissional se o rating agregado estiver errado
      if (reviewed.isNotEmpty) {
        final count = reviewed.length;
        final avg = reviewed
                .map((r) => (r['rating'] as int))
                .reduce((a, b) => a + b) /
            count;
        final avgRounded = double.parse(avg.toStringAsFixed(1));
        final vet = selectedVet.value;
        if (vet != null &&
            (vet.rating != avgRounded || vet.reviewCount != count)) {
          // Atualiza em memória imediatamente (independente do Firestore)
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
            );
            allVets.removeAt(idx);
            allVets.insert(idx, updated);
            selectedVet.value = updated;
            _filter();
          }
          // Persiste no Firestore em background (falha silenciosa)
          FirebaseFirestore.instance
              .collection('users')
              .doc(vetId)
              .update({'rating': avgRounded, 'reviewCount': count})
              .catchError((_) {});
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
