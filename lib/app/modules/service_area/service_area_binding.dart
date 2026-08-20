import 'package:get/get.dart';
import 'service_area_controller.dart';

class ServiceAreaBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ServiceAreaController());
  }
}
