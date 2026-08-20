import 'package:get/get.dart';
import 'home_controller.dart';
import '../vets/vets_controller.dart';
import '../scheduling/scheduling_controller.dart';
import '../profile/profile_controller.dart';
import '../prontuario/prontuario_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(() => HomeController(), fenix: true);
    Get.lazyPut<VetsController>(() => VetsController(), fenix: true);
    Get.lazyPut<SchedulingController>(() => SchedulingController(), fenix: true);
    Get.lazyPut<ProfileController>(() => ProfileController(), fenix: true);
    if (!Get.isRegistered<ProntuarioController>()) {
      Get.put<ProntuarioController>(ProntuarioController(), permanent: true);
    }
  }
}
