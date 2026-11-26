import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/service_area_model.dart';
import '../../data/models/vet_model.dart';
import '../../utils/brazilian_states.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/public_reads_service.dart';
import '../../services/region_service.dart';
import '../../widgets/guest_widgets.dart';
import '../../services/taxonomy_service.dart';
import '../../services/municipios_coords.dart';

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
  // "Ver profissionais perto de você": troca a restrição de cidade/bairro por
  // um raio (centro da cidade do tutor → cidades atendidas pelo profissional).
  // O nome ficou do comportamento antigo (mostrava todas as cidades).
  final showOtherCities = false.obs;
  static const double nearbyRadiusKm = 50;
  // vetId → (km até a cidade atendida mais próxima, nome dessa cidade)
  final Map<String, (double, String)> _nearby = {};
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
    // Controlador permanente: ao trocar de conta (visitante → login, logout),
    // recarrega o endereço do tutor e reabre a escuta com a credencial nova.
    String key(User? u) => '${u?.uid}|${u?.isAnonymous}';
    _lastUid = key(FirebaseAuth.instance.currentUser);
    // userChanges (não authStateChanges): cobre também o visitante anônimo
    // que vincula a conta e mantém o mesmo uid.
    _authSub = FirebaseAuth.instance.userChanges().listen((u) {
      if (key(u) == _lastUid) return;
      _lastUid = key(u);
      filterByArea.value = false;
      showOtherCities.value = false;
      _lastAddrKey = null;
      _loadTutorAddress();
      _loadVets();
    });
  }

  String? _lastUid;
  StreamSubscription<User?>? _authSub;

  Future<void> _loadTutorAddress() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;
      if (uid == null) return;
      // Visitante: não há perfil; usa a cidade que ele escolheu.
      // Lê direto do Firebase (não AuthService.isGuest): na troca de conta os
      // dois ouvintes de login disputam a ordem.
      if (user!.isAnonymous) {
        await _userSub?.cancel();
        _userSub = null;
        _lastAddrKey = null;
        applyRegion();
        return;
      }
      // Escuta o cadastro (não lê uma vez só): endereço salvo/trocado no
      // Perfil reflete na Busca na hora.
      await _userSub?.cancel();
      _userSub = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()
          .listen((doc) => _applyUserAddress(doc.data()), onError: (_) {});
    } catch (_) {
      // Sem endereço: o filtro simplesmente fica indisponível.
    }
  }

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  String? _lastAddrKey;

  Future<void> _applyUserAddress(Map<String, dynamic>? data) async {
    try {
      final addrs = List<Map<String, dynamic>>.from(data?['addresses'] ?? []);
      // O cadastro muda por outros motivos (pet, foto, token): só reaplica
      // quando o endereço principal mudou, para não desfazer o filtro escolhido.
      final f = addrs.isEmpty ? null : addrs.first;
      final key = f == null
          ? ''
          : '${f['state']}|${f['city']}|${f['neighborhood']}';
      if (key == _lastAddrKey) return;
      _lastAddrKey = key;
      if (addrs.isEmpty) {
        // Conta sem endereço ainda: usa a cidade escolhida como visitante, se houver.
        applyRegion();
        return;
      }
      final a = addrs.first;
      _tutorUf = _toUfSigla((a['state'] ?? '').toString());
      _tutorCity = (a['city'] ?? '').toString().trim();
      _tutorBairro = (a['neighborhood'] ?? '').toString().trim();
      // Endereços antigos digitados à mão ("Rio", UF vazia/por extenso):
      // troca pelo nome oficial do IBGE para bater com a área do profissional.
      await MunicipiosCoords.ensureLoaded();
      final oficial = MunicipiosCoords.canonical(_tutorUf, _tutorCity);
      if (oficial != null) {
        _tutorUf = oficial.$1;
        _tutorCity = oficial.$2;
      }
      if (_tutorCity.isNotEmpty) {
        tutorAddressLabel.value =
            _tutorBairro.isNotEmpty ? '$_tutorBairro, $_tutorCity' : _tutorCity;
        // Filtro por região ligado por padrão quando há endereço cadastrado —
        // atendimento é a domicílio, não faz sentido listar por padrão
        // profissionais de outro estado/cidade. O tutor ainda pode desligar
        // manualmente (toggleAreaFilter) se quiser ver todo mundo.
        filterByArea.value = true;
        _filter();
        update();
      }
    } catch (_) {
      // Sem endereço: o filtro simplesmente fica indisponível.
    }
  }

  bool get isGuest => Get.find<AuthService>().isGuest;

  /// Aplica a cidade escolhida no seletor (visitante, ou conta sem endereço):
  /// filtra a busca por quem atende a cidade, igual a um endereço sem bairro.
  void applyRegion() {
    final r = Get.find<RegionService>();
    if (!r.hasRegion) {
      _tutorUf = '';
      _tutorCity = '';
      _tutorBairro = '';
      tutorAddressLabel.value = '';
      filterByArea.value = false;
    } else {
      _tutorUf = r.uf.value;
      _tutorCity = r.city.value;
      _tutorBairro = '';
      tutorAddressLabel.value = r.label;
      filterByArea.value = true;
      showOtherCities.value = false;
    }
    _filter();
    update();
  }

  /// UF → (cidade → nº de profissionais que atendem), a partir da vitrine.
  Map<String, Map<String, int>> coverageByState() {
    final out = <String, Map<String, int>>{};
    for (final v in allVets) {
      final a = v.areaAtuacao;
      if (a == null) continue;
      for (final c in a.cidades) {
        if (c.nome.trim().isEmpty) continue;
        final m = out.putIfAbsent(a.estado, () => <String, int>{});
        m[c.nome] = (m[c.nome] ?? 0) + 1;
      }
    }
    return out;
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

  Future<void> showAllCities() async {
    showOtherCities.value = true;
    await MunicipiosCoords.ensureLoaded();
    _filter();
    update();
  }

  /// Calcula, para cada profissional, a cidade atendida mais próxima do
  /// centro da cidade do tutor. Fora do raio (ou sem coordenada) não entra.
  void _computeNearby() {
    _nearby.clear();
    if (!MunicipiosCoords.isLoaded || _tutorCity.isEmpty) return;
    final origem = MunicipiosCoords.ibgeOf(_tutorUf, _tutorCity);
    if (origem == null) return;
    for (final v in allVets) {
      final a = v.areaAtuacao;
      if (a == null) continue;
      (double, String)? best;
      for (final c in a.cidades) {
        final ibge = c.ibgeId.isNotEmpty
            ? c.ibgeId
            : MunicipiosCoords.ibgeOf(a.estado, c.nome);
        if (ibge == null) continue;
        final km = MunicipiosCoords.distanceKm(origem, ibge);
        if (km == null || km > nearbyRadiusKm) continue;
        if (best == null || km < best.$1) best = (km, c.nome);
      }
      if (best != null) _nearby[v.id] = best;
    }
  }

  /// Texto de distância do cartão no modo "perto de você", ex.:
  /// "Atende sua cidade" ou "Atende Niterói · a ~12 km". Nulo fora do modo.
  String? nearbyLabel(VetModel v) {
    if (!showOtherCities.value) return null;
    final n = _nearby[v.id];
    if (n == null) return null;
    if (n.$1 < 1) return 'Atende sua cidade';
    return 'Atende ${n.$2} · a ~${n.$1.round()} km';
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
    // No modo "perto de você", tocar na pílula volta ao filtro do endereço.
    if (showOtherCities.value) {
      showOtherCities.value = false;
      _filter();
      update();
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
    if (showOtherCities.value) _computeNearby();
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
      final matchesArea = showOtherCities.value
          ? _nearby.containsKey(v.id)
          : (filterByArea.value
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
    // Perto de você: a distância manda (faixas de 5 km); dentro da faixa
    // vale a ordenação escolhida (desempate explícito: sort não é estável).
    if (showOtherCities.value) {
      int faixa(VetModel v) => ((_nearby[v.id]?.$1 ?? 999) / 5).floor();
      final ordem = {for (var i = 0; i < result.length; i++) result[i].id: i};
      result.sort((a, b) {
        final f = faixa(a).compareTo(faixa(b));
        return f != 0 ? f : ordem[a.id]!.compareTo(ordem[b.id]!);
      });
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
    // Visitante: a conta é pedida aqui, depois de ver profissional e preços.
    if (Get.find<AuthService>().isGuest) {
      showGuestWall(vetId: vet.id);
      return;
    }
    Get.toNamed(Routes.scheduling);
  }

  @override
  void onClose() {
    _vetsSub?.cancel();
    _authSub?.cancel();
    _userSub?.cancel();
    searchController.dispose();
    super.onClose();
  }
}
