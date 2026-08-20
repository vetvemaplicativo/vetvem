import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';
import '../../../services/auth_exceptions.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_theme.dart';
import '../../terms/terms_view.dart';

class LoginController extends GetxController {
  final _auth = Get.find<AuthService>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final isLoading = false.obs;
  final isPasswordVisible = false.obs;

  void togglePasswordVisibility() => isPasswordVisible.toggle();

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Informe seu e-mail';
    if (!GetUtils.isEmail(value)) return 'E-mail inválido';
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Informe sua senha';
    if (value.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  Future<void> login() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;
    try {
      await _auth.signInWithEmailAndPassword(
        emailController.text,
        passwordController.text,
      );
      if (await _isBlocked()) return;
      if (!await _termsOk()) return;
      Get.offAllNamed(Routes.home);
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Ocorreu um erro. Tente novamente.');
    } finally {
      isLoading.value = false;
    }
  }

  /// Contas antigas sem aceite: mostra os termos; recusa = logout.
  Future<bool> _termsOk() async {
    final ok = await TermsView.ensureAccepted();
    if (!ok) {
      await FirebaseAuth.instance.signOut();
      _showError('É necessário aceitar os Termos de Uso para usar o app.');
    }
    return ok;
  }

  Future<void> loginWithGoogle() async {
    isLoading.value = true;
    try {
      await _auth.signInWithGoogle();
      if (await _isBlocked()) return;
      if (!await _termsOk()) return;
      Get.offAllNamed(Routes.home);
    } on AuthException catch (e) {
      if (e.message != AuthExceptions.googleCancelled.message) {
        _showError(e.message);
      }
    } catch (_) {
      _showError('Ocorreu um erro. Tente novamente.');
    } finally {
      isLoading.value = false;
    }
  }

  /// Conta bloqueada pelo painel admin: desloga e avisa.
  Future<bool> _isBlocked() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.data()?['blocked'] == true) {
        await FirebaseAuth.instance.signOut();
        _showError('Conta bloqueada. Entre em contato com o suporte.');
        return true;
      }
    } catch (_) {}
    return false;
  }

  void goToRegister() => Get.toNamed(Routes.register);

  void goToForgotPassword() {
    final ctrl = TextEditingController(text: emailController.text.trim());
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Recuperar senha',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informe seu e-mail e enviaremos um link para redefinir sua senha.',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'seu@email.com',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          Obx(() => TextButton(
            onPressed: isLoading.value
                ? null
                : () => _sendResetEmail(ctrl.text.trim()),
            child: isLoading.value
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Enviar',
                    style: TextStyle(fontWeight: FontWeight.bold)),
          )),
        ],
      ),
    );
  }

  Future<void> _sendResetEmail(String email) async {
    if (email.isEmpty) {
      _showError('Informe seu e-mail.');
      return;
    }
    isLoading.value = true;
    try {
      await _auth.sendPasswordResetEmail(email);
      Get.back();
      _showSuccess('E-mail enviado! Verifique sua caixa de entrada.');
    } on AuthException catch (e) {
      _showError(e.message);
    } finally {
      isLoading.value = false;
    }
  }

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

  void _showSuccess(String message) {
    Get.snackbar('Pronto!', message,
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF22C55E),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 4),
        icon: const Icon(Icons.check_circle_outline, color: Colors.white));
  }

  void _showInfo(String message) {
    Get.snackbar(
      'Em breve',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.textDark,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
