import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../routes/app_routes.dart';
import '../../services/notification_service.dart';
import '../profile/profile_controller.dart';

enum PaymentMethod { pix, card }
enum PaymentStatus { selecting, pixWaiting, cardForm, processing, approved, rejected }

class PaymentController extends GetxController {
  // ── Arguments ─────────────────────────────────────────────────────
  late final String appointmentId;
  late final String vetId;
  late final String vetName;
  late final String tutorName;
  late final String petName;
  late final String petSpecies;
  late final String petBreed;
  late final String petSex;
  late final String petAge;
  late final bool petCastrated;
  late final String petPhotoBase64;
  late final String serviceName;
  late final String appointmentDate;
  late final String appointmentTime;
  late final String appointmentAddress;
  late final double price;

  // ── MP Public Key (segura no cliente — só cria tokens, não cobra) ──
  static const _mpPublicKey = 'APP_USR-8b0f8ba4-7197-48f6-845b-bb96d906cd8f';

  // ── Cloud Functions base URL ───────────────────────────────────────
  static const _cfBase = 'https://southamerica-east1-vetvem-18bf4.cloudfunctions.net';

  final status = PaymentStatus.selecting.obs;
  final selectedMethod = Rx<PaymentMethod?>(null);

  // ── Pix ───────────────────────────────────────────────────────────
  final pixCountdown = 1800.obs; // 30 min (alinhado com CF)
  final pixLoading = false.obs;
  final pixCopyPaste = ''.obs;
  final pixQrCodeBase64 = ''.obs;
  Timer? _pixTimer;
  StreamSubscription? _pixStatusSub;

  // ── Card ──────────────────────────────────────────────────────────
  final cardNumberController = TextEditingController();
  final cardHolderController = TextEditingController();
  final expiryController     = TextEditingController();
  final cvvController        = TextEditingController();
  final cpfController        = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final isCardFlipped = false.obs;

  // Chama uma Cloud Function callable via HTTP direto (evita bug do SDK cloud_functions)
  Future<Map<String, dynamic>> _callFunction(String name, Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('currentUser nulo — faça login novamente');
    final idToken = await user.getIdToken(true); // force refresh
    final res = await http.post(
      Uri.parse('$_cfBase/$name'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(data),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error']?.toString() ?? 'HTTP ${res.statusCode}');
    }
    return body['result'] as Map<String, dynamic>;
  }

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    appointmentId    = args['appointmentId'] ?? '';
    vetId            = args['vetId'] ?? '';
    vetName          = args['vetName'] ?? 'Veterinário';
    tutorName        = args['tutorName'] ?? '';
    petName          = args['petName'] ?? 'Pet';
    petSpecies       = args['petSpecies'] ?? 'dog';
    petBreed         = args['petBreed'] ?? '';
    petSex           = args['petSex'] ?? '';
    petAge           = args['petAge'] ?? '';
    petCastrated     = args['petCastrated'] ?? false;
    petPhotoBase64   = args['petPhotoBase64'] ?? '';
    serviceName      = args['serviceName'] ?? '';
    appointmentDate  = args['date'] ?? '';
    appointmentTime  = args['time'] ?? '';
    appointmentAddress = args['address'] ?? '';
    price = (args['price'] as num?)?.toDouble() ?? 0.0;
  }

  // ── Pix ───────────────────────────────────────────────────────────

  void selectPix() {
    selectedMethod.value = PaymentMethod.pix;
    status.value = PaymentStatus.pixWaiting;
    _generatePixPayment();
  }

  Future<void> _generatePixPayment() async {
    pixLoading.value = true;
    pixCopyPaste.value = '';
    pixQrCodeBase64.value = '';
    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email ?? 'cliente@vetvem.com.br';
      final parts = tutorName.trim().split(' ');
      final fn = parts.isNotEmpty ? parts.first : 'Cliente';
      final ln = parts.length > 1 ? parts.last : 'VetVem';

      final data = await _callFunction('createPixPayment', {
        'appointmentId': appointmentId,
        'amount': price,
        'description': serviceName.isNotEmpty ? serviceName : 'Consulta veterinária VetVem',
        'email': email,
        'firstName': fn,
        'lastName': ln,
      });

      pixCopyPaste.value = data['pixCopyPaste'] as String? ?? '';
      pixQrCodeBase64.value = data['pixQrCodeBase64'] as String? ?? '';

      _startPixTimer();
      _listenPixStatus();
    } catch (e) {
      Get.snackbar('Erro PIX', e.toString().replaceFirst('Exception: ', ''),
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 6));
      status.value = PaymentStatus.selecting;
    } finally {
      pixLoading.value = false;
    }
  }

  void _listenPixStatus() {
    if (appointmentId.isEmpty) return;
    _pixStatusSub?.cancel();
    _pixStatusSub = FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      if (data == null) return;
      final ps = data['paymentStatus'] as String? ?? '';
      if (ps == 'approved') {
        _pixStatusSub?.cancel();
        _pixTimer?.cancel();
        status.value = PaymentStatus.approved;
        _notifyVet('pix');
      }
    });
  }

  void _startPixTimer() {
    pixCountdown.value = 1800;
    _pixTimer?.cancel();
    _pixTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (pixCountdown.value > 0) {
        pixCountdown.value--;
      } else {
        t.cancel();
        _pixStatusSub?.cancel();
        status.value = PaymentStatus.selecting;
      }
    });
  }

  String get pixFormattedCountdown {
    final m = pixCountdown.value ~/ 60;
    final s = pixCountdown.value % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void selectCard() {
    selectedMethod.value = PaymentMethod.card;
    status.value = PaymentStatus.cardForm;
  }

  // ── Card ──────────────────────────────────────────────────────────

  Future<void> submitCard() async {
    if (!formKey.currentState!.validate()) return;
    status.value = PaymentStatus.processing;

    try {
      final digits = cardNumberController.text.replaceAll(RegExp(r'\D'), '');
      final last4 = digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
      final expParts = expiryController.text.split('/');
      final month = int.tryParse(expParts[0]) ?? 1;
      final year = 2000 + (int.tryParse(expParts.length > 1 ? expParts[1] : '25') ?? 25);
      final cpf = cpfController.text.replaceAll(RegExp(r'\D'), '');

      // 1. Determina payment_method_id pelo BIN
      final paymentMethodId = await _getPaymentMethodId(
          digits.length >= 6 ? digits.substring(0, 6) : digits);

      // 2. Tokeniza o cartão via MP API (public key é segura no cliente)
      final tokenRes = await http.post(
        Uri.parse(
            'https://api.mercadopago.com/v1/card_tokens?public_key=$_mpPublicKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'card_number': digits,
          'security_code': cvvController.text,
          'expiration_month': month,
          'expiration_year': year,
          'cardholder': {
            'name': cardHolderController.text.trim(),
            if (cpf.isNotEmpty)
              'identification': {'type': 'CPF', 'number': cpf},
          },
        }),
      );

      if (tokenRes.statusCode != 201) {
        final body = jsonDecode(tokenRes.body) as Map<String, dynamic>;
        final cause = (body['cause'] as List?)?.isNotEmpty == true
            ? (body['cause'] as List).first['description'] as String?
            : null;
        throw Exception(cause ?? 'Erro ao tokenizar cartão');
      }

      final tokenData = jsonDecode(tokenRes.body) as Map<String, dynamic>;
      final token = tokenData['id'] as String;

      // 3. Chama a Cloud Function para cobrar (CPF/nome reduzem falsos
      // positivos do antifraude)
      final user = FirebaseAuth.instance.currentUser;
      final payerName = user?.displayName?.trim() ?? '';
      final nameParts = payerName.split(' ');
      final result = await _callFunction('createPayment', {
        'appointmentId': appointmentId,
        'amount': price,
        'description': serviceName.isNotEmpty ? serviceName : 'Consulta veterinária VetVem',
        'email': user?.email ?? 'cliente@vetvem.com.br',
        'token': token,
        'paymentMethodId': paymentMethodId,
        'installments': 1,
        if (cpf.isNotEmpty) 'cpf': cpf,
        if (nameParts.isNotEmpty && nameParts.first.isNotEmpty)
          'firstName': nameParts.first,
        if (nameParts.length > 1) 'lastName': nameParts.sublist(1).join(' '),
      });

      final payStatus = result['status'] as String? ?? '';
      final statusDetail = result['statusDetail'] as String? ?? '';

      if (payStatus == 'approved') {
        // Guarda o cartão no cofre do MP: próximas compras pedem só o CVV
        await _saveCardToVault(
          digits: digits,
          month: month,
          year: year,
          cpf: cpf,
          last4: last4,
          email: user?.email ?? '',
        );
        status.value = PaymentStatus.approved;
        await _notifyVet('card');
      } else {
        status.value = PaymentStatus.rejected;
        Get.snackbar('Pagamento recusado', _rejectionMessage(statusDetail),
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 6));
      }
    } catch (e) {
      Get.snackbar('Cartão recusado',
          e.toString().replaceFirst('Exception: ', ''),
          snackPosition: SnackPosition.TOP);
      status.value = PaymentStatus.rejected;
    }
  }

  /// Traduz o status_detail do Mercado Pago para o usuário.
  String _rejectionMessage(String detail) {
    switch (detail) {
      case 'cc_rejected_bad_filled_security_code':
        return 'Código de segurança (CVV) incorreto.';
      case 'cc_rejected_bad_filled_date':
        return 'Data de validade incorreta.';
      case 'cc_rejected_bad_filled_card_number':
        return 'Número do cartão incorreto.';
      case 'cc_rejected_bad_filled_other':
        return 'Confira os dados do cartão e tente novamente.';
      case 'cc_rejected_insufficient_amount':
        return 'Limite ou saldo insuficiente.';
      case 'cc_rejected_call_for_authorize':
        return 'O banco pediu autorização — ligue para o emissor do cartão e tente de novo.';
      case 'cc_rejected_disabled_card':
        return 'Cartão desativado — contate o emissor.';
      case 'cc_rejected_high_risk':
        return 'Recusado pela análise antifraude do Mercado Pago. Tente PIX ou outro cartão.';
      case 'cc_rejected_blacklist':
        return 'Cartão não permitido. Tente outro método.';
      case 'cc_rejected_duplicated_payment':
        return 'Pagamento duplicado — aguarde alguns minutos.';
      case 'cc_rejected_card_error':
        return 'Não foi possível processar o cartão. Tente novamente.';
      default:
        return detail.isEmpty
            ? 'Cartão recusado pelo emissor. Tente outro método.'
            : 'Recusado: $detail';
    }
  }

  /// Tokeniza de novo (tokens são de uso único) e envia à function saveCard,
  /// que anexa o cartão ao customer MP. Falha aqui não afeta o pagamento.
  Future<void> _saveCardToVault({
    required String digits,
    required int month,
    required int year,
    required String cpf,
    required String last4,
    required String email,
  }) async {
    try {
      if (email.isEmpty || cardHolderController.text.trim().isEmpty) return;
      final tokenRes = await http.post(
        Uri.parse(
            'https://api.mercadopago.com/v1/card_tokens?public_key=$_mpPublicKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'card_number': digits,
          'security_code': cvvController.text,
          'expiration_month': month,
          'expiration_year': year,
          'cardholder': {
            'name': cardHolderController.text.trim(),
            if (cpf.isNotEmpty)
              'identification': {'type': 'CPF', 'number': cpf},
          },
        }),
      );
      if (tokenRes.statusCode != 201) return;
      final token =
          (jsonDecode(tokenRes.body) as Map<String, dynamic>)['id'] as String;

      final saved = await _callFunction('saveCard', {
        'token': token,
        'email': email,
      });

      final profile = Get.find<ProfileController>();
      profile.mpCustomerId.value = saved['customerId'] as String? ?? '';
      profile.addCard(SavedCard(
        holderName: cardHolderController.text.trim().toUpperCase(),
        lastFour: saved['lastFour'] as String? ?? last4,
        expiry: expiryController.text.trim(),
        brand: _detectBrand(digits),
        mpCardId: saved['cardId'] as String? ?? '',
        paymentMethodId: saved['paymentMethodId'] as String? ?? '',
      ));
    } catch (_) {
      // Sem cofre: salva só a referência visual, como antes
      Get.find<ProfileController>().addCard(SavedCard(
        holderName: cardHolderController.text.trim().toUpperCase(),
        lastFour: last4,
        expiry: expiryController.text.trim(),
        brand: _detectBrand(digits),
      ));
    }
  }

  /// Pagamento rápido com cartão do cofre MP: só precisa do CVV.
  Future<void> payWithSavedCard(SavedCard card, String cvv) async {
    status.value = PaymentStatus.processing;
    try {
      final profile = Get.find<ProfileController>();
      final customerId = profile.mpCustomerId.value;
      if (!card.canQuickPay || customerId.isEmpty) {
        throw Exception('Cartão sem pagamento rápido — use o formulário');
      }

      // Tokeniza com card_id + CVV (public key, seguro no cliente)
      final tokenRes = await http.post(
        Uri.parse(
            'https://api.mercadopago.com/v1/card_tokens?public_key=$_mpPublicKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'card_id': card.mpCardId, 'security_code': cvv}),
      );
      if (tokenRes.statusCode != 201) {
        throw Exception('CVV inválido. Confira o código de segurança.');
      }
      final token =
          (jsonDecode(tokenRes.body) as Map<String, dynamic>)['id'] as String;

      final user = FirebaseAuth.instance.currentUser;
      final result = await _callFunction('createPayment', {
        'appointmentId': appointmentId,
        'amount': price,
        'description':
            serviceName.isNotEmpty ? serviceName : 'Consulta veterinária VetVem',
        'email': user?.email ?? 'cliente@vetvem.com.br',
        'token': token,
        'paymentMethodId': card.paymentMethodId,
        'installments': 1,
        'customerId': customerId,
      });

      if ((result['status'] as String? ?? '') == 'approved') {
        status.value = PaymentStatus.approved;
        await _notifyVet('card');
      } else {
        status.value = PaymentStatus.rejected;
        Get.snackbar('Pagamento recusado',
            _rejectionMessage(result['statusDetail'] as String? ?? ''),
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 6));
      }
    } catch (e) {
      Get.snackbar('Cartão recusado',
          e.toString().replaceFirst('Exception: ', ''),
          snackPosition: SnackPosition.TOP);
      status.value = PaymentStatus.rejected;
    }
  }

  Future<String> _getPaymentMethodId(String bin) async {
    try {
      // Endpoint oficial de parcelas: retorna o payment_method_id do BIN
      final res = await http.get(Uri.parse(
          'https://api.mercadopago.com/v1/payment_methods/installments'
          '?public_key=$_mpPublicKey&bin=$bin&amount=${price.toStringAsFixed(2)}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        if (data.isNotEmpty) {
          final id = data.first['payment_method_id'] as String?;
          if (id != null && id.isNotEmpty) return id;
        }
      }
    } catch (_) {}
    return _fallbackMethodId(bin);
  }

  String _fallbackMethodId(String digits) {
    // Elo antes de Visa/Master: seus BINs começam com 4, 5 e 6
    if (RegExp(r'^(636368|438935|504175|451416|636297|5067|4576|4011|506699)')
        .hasMatch(digits)) return 'elo';
    if (digits.startsWith('4')) return 'visa';
    if (RegExp(r'^5[1-5]').hasMatch(digits)) return 'master';
    if (RegExp(r'^2(2[2-9]|[3-6]|7[01])').hasMatch(digits)) return 'master'; // série 2221–2720
    if (RegExp(r'^3[47]').hasMatch(digits)) return 'amex';
    if (digits.startsWith('384') || digits.startsWith('606282')) return 'hipercard';
    if (RegExp(r'^(301|305|36|38)').hasMatch(digits)) return 'diners';
    return 'master';
  }

  String _detectBrand(String digits) => ProfileController.detectBrand(digits);

  // ── Notificação ao vet ────────────────────────────────────────────

  Future<void> _notifyVet(String method) async {
    try {
      String resolvedVetId = vetId;
      String resolvedPetName = petName;
      if (appointmentId.isNotEmpty && (resolvedVetId.isEmpty || resolvedPetName.isEmpty)) {
        final snap = await FirebaseFirestore.instance
            .collection('appointments')
            .doc(appointmentId)
            .get();
        final d = snap.data() ?? {};
        resolvedVetId = resolvedVetId.isNotEmpty ? resolvedVetId : (d['vetId'] as String? ?? '');
        resolvedPetName = resolvedPetName.isNotEmpty ? resolvedPetName : (d['petName'] as String? ?? 'seu pet');
      }
      if (resolvedVetId.isNotEmpty) {
        await NotificationService.sendTo(
          toUid: resolvedVetId,
          title: '💳 Pagamento confirmado!',
          body: 'O tutor pagou a consulta de $resolvedPetName via ${method == 'pix' ? 'PIX' : 'cartão'}. O valor será repassado em D+2 após a consulta.',
        );
      }
    } catch (_) {}
  }

  // ── Navegação ─────────────────────────────────────────────────────

  void retryCard() => status.value = PaymentStatus.cardForm;

  void goToHome() => Get.offAllNamed(Routes.home);

  void goToConsultas() => Get.offAllNamed(Routes.home, arguments: {'tab': 2});

  @override
  void onClose() {
    _pixTimer?.cancel();
    _pixStatusSub?.cancel();
    cardNumberController.dispose();
    cardHolderController.dispose();
    expiryController.dispose();
    cvvController.dispose();
    cpfController.dispose();
    super.onClose();
  }
}
