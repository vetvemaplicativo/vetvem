import 'package:get/get.dart';
import 'rating_controller.dart';
import '../profile/profile_controller.dart';

class RatingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => RatingController());
    // ProfileController pode já estar ativo; só registra se não estiver
    if (!Get.isRegistered<ProfileController>()) {
      Get.lazyPut(() => ProfileController(), fenix: true);
    }
  }
}
