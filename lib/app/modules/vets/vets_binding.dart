import 'package:get/get.dart';
import 'vets_controller.dart';

class VetsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<VetsController>(() => VetsController(), fenix: true);
  }
}
