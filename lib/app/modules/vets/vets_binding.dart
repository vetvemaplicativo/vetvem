import 'package:get/get.dart';
import 'vets_controller.dart';

class VetsBinding extends Bindings {
  @override
  void dependencies() {
    // Mesma instância permanente da Home (ver HomeBinding).
    if (!Get.isRegistered<VetsController>()) {
      Get.put<VetsController>(VetsController(), permanent: true);
    }
  }
}
