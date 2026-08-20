import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../routes/app_routes.dart';

class SplashController extends GetxController {
  Timer? _timer;

  @override
  void onReady() {
    super.onReady();
    _timer = Timer(const Duration(seconds: 2), _navigate);
  }

  void _navigate() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Get.offAllNamed(Routes.home);
    } else {
      Get.offAllNamed(Routes.login);
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
