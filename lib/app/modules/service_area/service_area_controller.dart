import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/service_area_model.dart';
import '../../services/ibge_service.dart';
import '../../theme/app_theme.dart';

class ServiceAreaController extends GetxController {
  final _ibge = Get.find<IbgeService>();
  final _firestore = FirebaseFirestore.instance;

  /// Uid do profissional sendo editado. Por padrão é o usuário logado, mas
  /// pode vir por argumento (`Get.arguments['uid']`) — útil enquanto o
  /// cadastro Pro não existe e para reuso futuro.
  late final String uid;

  // ── Estado (UF) ──────────────────────────────────────────────────
  final selectedUf = ''.obs;

  // ── Cidades ──────────────────────────────────────────────────────
  final municipios = <IbgeMunicipio>[].obs;
  final isLoadingCities = false.obs;
  final cityLoadError = false.obs;
  final citySearchController = TextEditingController();
  final citySearchQuery = ''.obs;

  // ── Seleção do profissional ──────────────────────────────────────
  final selectedCities = <AreaCidade>[].obs;

  final isLoadingExisting = true.obs;
  final isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    uid = (args is Map && args['uid'] is String && args['uid'].isNotEmpty)
        ? args['uid']
        : FirebaseAuth.instance.currentUser?.uid ?? '';
    citySearchController.addListener(
        () => citySearchQuery.value = citySearchController.text);
    _loadExisting();
  }

  List<IbgeMunicipio> get filteredMunicipios {
    final q = normalizeSearchText(citySearchQuery.value);
    if (q.isEmpty) return municipios;
    return municipios
        .where((m) => normalizeSearchText(m.nome).contains(q))
        .toList();
  }

  bool isCitySelected(String ibgeId) =>
      selectedCities.any((c) => c.ibgeId == ibgeId);

  // ── Carga inicial ────────────────────────────────────────────────

  Future<void> _loadExisting() async {
    if (uid.isEmpty) {
      isLoadingExisting.value = false;
      return;
    }
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final area = AreaAtuacao.fromMap(
          doc.data()?['area_atuacao'] as Map<String, dynamic>?);
      if (!area.isEmpty) {
        selectedCities.assignAll(area.cidades);
        selectedUf.value = area.estado;
        await loadCities();
      }
    } catch (_) {
      // Sem dados prévios ou sem rede: começa em branco, o save resolve.
    } finally {
      isLoadingExisting.value = false;
    }
  }

  // ── UF ───────────────────────────────────────────────────────────

  Future<void> selectUf(String uf) async {
    if (uf == selectedUf.value) return;
    if (selectedCities.isNotEmpty) {
      final confirmed = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Trocar de estado?'),
          content: const Text(
              'As cidades e bairros já selecionados serão removidos.'),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Trocar',
                  style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      selectedCities.clear();
    }
    selectedUf.value = uf;
    await loadCities();
  }

  Future<void> loadCities() async {
    if (selectedUf.value.isEmpty) return;
    isLoadingCities.value = true;
    cityLoadError.value = false;
    try {
      final result = await _ibge.getMunicipios(selectedUf.value);
      municipios.assignAll(result);
    } catch (_) {
      municipios.clear();
      cityLoadError.value = true;
    } finally {
      isLoadingCities.value = false;
    }
  }

  // ── Cidades ──────────────────────────────────────────────────────

  void toggleCity(IbgeMunicipio municipio) {
    final index = selectedCities.indexWhere((c) => c.ibgeId == municipio.id);
    if (index >= 0) {
      selectedCities.removeAt(index);
    } else {
      selectedCities
          .add(AreaCidade(nome: municipio.nome, ibgeId: municipio.id));
    }
  }

  void removeCity(String ibgeId) =>
      selectedCities.removeWhere((c) => c.ibgeId == ibgeId);

  // ── Bairros ──────────────────────────────────────────────────────

  /// Adiciona um bairro à cidade. Retorna null se ok, ou mensagem de erro.
  String? addBairro(String ibgeId, String bairro) {
    final normalized = normalizeSearchText(bairro);
    if (normalized.isEmpty) return 'Digite o nome do bairro';
    final index = selectedCities.indexWhere((c) => c.ibgeId == ibgeId);
    if (index < 0) return null;
    final city = selectedCities[index];
    final exists =
        city.bairros.any((b) => normalizeSearchText(b) == normalized);
    if (exists) return 'Esse bairro já foi adicionado';
    selectedCities[index] =
        city.copyWith(bairros: [...city.bairros, bairro.trim()]);
    return null;
  }

  void removeBairro(String ibgeId, String bairro) {
    final index = selectedCities.indexWhere((c) => c.ibgeId == ibgeId);
    if (index < 0) return;
    final city = selectedCities[index];
    selectedCities[index] = city.copyWith(
        bairros: city.bairros.where((b) => b != bairro).toList());
  }

  void toggleCidadeToda(String ibgeId, bool value) {
    final index = selectedCities.indexWhere((c) => c.ibgeId == ibgeId);
    if (index < 0) return;
    selectedCities[index] =
        selectedCities[index].copyWith(atendeCidadeToda: value);
  }

  // ── Validação e save ─────────────────────────────────────────────

  String? validate() {
    if (selectedUf.value.isEmpty) return 'Selecione o estado onde você atende';
    if (selectedCities.isEmpty) {
      return 'Adicione pelo menos uma cidade onde você atende';
    }
    for (final city in selectedCities) {
      if (!city.atendeCidadeToda && city.bairros.isEmpty) {
        return 'Em ${city.nome}: adicione ao menos um bairro '
            'ou marque "Atendo a cidade toda"';
      }
    }
    return null;
  }

  Future<void> save() async {
    final error = validate();
    if (error != null) {
      _showError(error);
      return;
    }
    if (uid.isEmpty) {
      _showError('Sessão expirada. Faça login novamente.');
      return;
    }

    isSaving.value = true;
    try {
      final area = AreaAtuacao(
        estado: selectedUf.value,
        cidades: selectedCities.toList(),
      );
      // Os dois campos sempre juntos, para nunca dessincronizar
      // exibição e busca.
      await _firestore.collection('users').doc(uid).update({
        'area_atuacao': area.toMap(),
        'area_atuacao_keys': area.toSearchKeys(),
      });
      Get.back();
      Get.snackbar(
        'Área de atuação salva',
        area.resumo,
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
      );
    } catch (_) {
      _showError('Não foi possível salvar. Verifique sua conexão '
          'e tente novamente.');
    } finally {
      isSaving.value = false;
    }
  }

  void _showError(String message) {
    Get.snackbar(
      'Atenção',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.error,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
      icon: const Icon(Icons.error_outline, color: Colors.white),
    );
  }

  @override
  void onClose() {
    citySearchController.dispose();
    super.onClose();
  }
}
