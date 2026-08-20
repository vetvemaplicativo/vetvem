import 'package:get/get.dart';
import 'scheduling_controller.dart';

class SchedulingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SchedulingController>(() => SchedulingController());
  }
}
