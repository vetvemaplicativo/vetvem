import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';
import '../../../services/auth_exceptions.dart';
import '../../../services/auth_service.dart';
import '../../../services/cep_service.dart' as cep;
import '../../terms/terms_view.dart';
import '../../../theme/app_theme.dart';

class RegisterController extends GetxController {
  final _auth = Get.find<AuthService>();

  // ── Step management ──────────────────────────────────────────────
  final currentStep = 0.obs;
  static const totalSteps = 3;

  // ── Step 1 — Dados pessoais ──────────────────────────────────────
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final cpfController = TextEditingController();
  final passwordController = TextEditingController();
  final isPasswordVisible = false.obs;
  final formStep2Key = GlobalKey<FormState>();

  // ── Step 3 — Endereço ────────────────────────────────────────────
  final cepController = TextEditingController();
  final streetController = TextEditingController();
  final numberController = TextEditingController();
  final complementController = TextEditingController();
  final neighborhoodController = TextEditingController();
  final cityController = TextEditingController();
  final stateController = TextEditingController();
  final referenceController = TextEditingController();
  final formStep3Key = GlobalKey<FormState>();
  final isLoadingCep = false.obs;

  // ── Step 4 — Pet ─────────────────────────────────────────────────
  final petSpecies = 'cat'.obs; // 'cat' | 'dog' | 'other'
  final petNameController = TextEditingController();
  final petBreedController = TextEditingController();
  final petAgeController = TextEditingController();
  final petWeightController = TextEditingController();
  final isCastrated = false.obs;
  final formStep4Key = GlobalKey<FormState>();
  final petPhotoBase64 = ''.obs;

  // ── Step 4 — Pet (extra) ─────────────────────────────────────────
  final petSex = 'male'.obs; // 'male' | 'female'

  final isLoading = false.obs;

  // ── Navigation ───────────────────────────────────────────────────

  void nextStep() {
    if (currentStep.value < totalSteps - 1) {
      currentStep.value++;
    }
  }

  void prevStep() {
    if (currentStep.value > 0) {
      currentStep.value--;
    } else {
      Get.back();
    }
  }

  // ── Step 1 ───────────────────────────────────────────────────────

  void togglePasswordVisibility() => isPasswordVisible.toggle();

  String? validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe seu nome';
    if (v.trim().length < 3) return 'Nome muito curto';
    return null;
  }

  String? validateEmail(String? v) {
    if (v == null || v.isEmpty) return 'Informe seu e-mail';
    if (!GetUtils.isEmail(v)) return 'E-mail inválido';
    return null;
  }

  String? validatePhone(String? v) {
    if (v == null || v.isEmpty) return 'Informe seu celular';
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return 'Número inválido';
    return null;
  }

  String? validateCpf(String? v) {
    if (v == null || v.isEmpty) return 'Informe seu CPF';
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) return 'CPF inválido';
    return null;
  }

  String? validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Informe uma senha';
    if (v.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  Future<void> proceedFromStep2() async {
    if (!formStep2Key.currentState!.validate()) return;
    isLoading.value = true;
    try {
      // Checagem de duplicados no servidor: antes do cadastro não há usuário
      // autenticado, e as regras do Firestore (corretamente) bloqueiam
      // consultas diretas — a function usa o Admin SDK.
      final res = await http
          .post(
            Uri.parse(
                'https://southamerica-east1-vetvem-18bf4.cloudfunctions.net/checkRegistration'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'cpf': cpfController.text.replaceAll(RegExp(r'\D'), ''),
              'email': emailController.text.trim().toLowerCase(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        _showError('Erro ao verificar cadastro. Tente novamente.');
        return;
      }
      final result =
          (jsonDecode(res.body) as Map<String, dynamic>)['result'] ?? {};
      if (result['cpfExists'] == true) {
        _showError('Este CPF já está cadastrado.');
        return;
      }
      if (result['emailExists'] == true) {
        _showError('Este e-mail já está cadastrado.');
        return;
      }

      nextStep();
    } catch (_) {
      _showError('Erro ao verificar cadastro. Tente novamente.');
    } finally {
      isLoading.value = false;
    }
  }

  // ── Step 3 ───────────────────────────────────────────────────────

  String? validateCep(String? v) {
    if (v == null || v.isEmpty) return 'Informe o CEP';
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) return 'CEP inválido';
    return null;
  }

  String? validateRequired(String? v) {
    if (v == null || v.trim().isEmpty) return 'Campo obrigatório';
    return null;
  }

  Future<void> lookupCep() async {
    final digits = cepController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) return;
    isLoadingCep.value = true;
    try {
      final result = await cep.lookupCep(digits);
      if (result == null) {
        Get.snackbar('CEP não encontrado', 'Verifique o CEP informado.',
            snackPosition: SnackPosition.TOP);
        return;
      }
      streetController.text = result.street;
      neighborhoodController.text = result.neighborhood;
      cityController.text = result.city;
      stateController.text = result.state;
    } catch (_) {
      Get.snackbar('Sem conexão',
          'Não foi possível buscar o CEP. Preencha o endereço manualmente.',
          snackPosition: SnackPosition.TOP);
    } finally {
      isLoadingCep.value = false;
    }
  }

  void proceedFromStep3() {
    if (formStep3Key.currentState!.validate()) nextStep();
  }

  // ── Step 4 ───────────────────────────────────────────────────────

  void selectPetSpecies(String species) => petSpecies.value = species;

  void selectPetSex(String sex) => petSex.value = sex;

  String? validatePetName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe o nome do pet';
    return null;
  }

  Future<void> pickPetPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 256,
      maxHeight: 256,
      imageQuality: 75,
    );
    if (picked == null) return;
    final bytes = await File(picked.path).readAsBytes();
    petPhotoBase64.value = 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  // Último passo: valida os dados do pet, mostra os Termos de Uso e,
  // aceitos, cria a conta. Antes havia uma etapa de "verificação SMS" aqui
  // no meio — nunca foi implementada de verdade (nenhum SMS era enviado, e
  // qualquer código de 4 dígitos passava), então foi removida.
  Future<void> proceedFromStep4() async {
    if (!formStep4Key.currentState!.validate()) return;

    // Aceite dos termos obrigatório antes de criar a conta
    final accepted = await Get.to<bool>(
          () => TermsView(
            onAccept: () => Get.back(result: true),
            onDecline: () => Get.back(result: false),
          ),
          fullscreenDialog: true,
        ) ??
        false;
    if (!accepted) return;

    isLoading.value = true;
    try {
      await _auth.createUserWithEmailAndPassword(
        nameController.text,
        emailController.text,
        passwordController.text,
        cpf: cpfController.text.replaceAll(RegExp(r'\D'), ''),
        phone: phoneController.text.trim(),
        address: {
          'label': 'Principal',
          'street': streetController.text.trim(),
          'number': numberController.text.trim(),
          'complement': complementController.text.trim(),
          'neighborhood': neighborhoodController.text.trim(),
          'city': cityController.text.trim(),
          'state': stateController.text.trim(),
          'cep': cepController.text.replaceAll(RegExp(r'\D'), ''),
        },
        pet: {
          'name': petNameController.text.trim(),
          'species': petSpecies.value,
          'breed': petBreedController.text.trim(),
          'age': petAgeController.text.trim(),
          'weight': petWeightController.text.trim(),
          'sex': petSex.value == 'female' ? 'Fêmea' : 'Macho',
          'castrated': isCastrated.value,
          'photoBase64': petPhotoBase64.value,
        },
      );
      await TermsView.recordAcceptance();
      Get.offAllNamed(Routes.home);
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Ocorreu um erro. Tente novamente.');
    } finally {
      isLoading.value = false;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  void _showError(String message) {
    Get.snackbar(
      'Erro',
      message,
      snackPosition: SnackPosition.BOTTOM,
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
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    cpfController.dispose();
    passwordController.dispose();
    cepController.dispose();
    streetController.dispose();
    numberController.dispose();
    complementController.dispose();
    neighborhoodController.dispose();
    cityController.dispose();
    stateController.dispose();
    referenceController.dispose();
    petNameController.dispose();
    petBreedController.dispose();
    petAgeController.dispose();
    petWeightController.dispose();
    super.onClose();
  }
}
