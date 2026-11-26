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
    // Uma só instância na sessão: ao entrar na conta a Home é recriada
    // (offAllNamed) e, com lazyPut, a tela ficava presa a dois controladores
    // (chips num, lista noutro) — filtro "sem efeito" e busca em carregamento.
    // A troca de conta é tratada dentro do próprio controlador.
    if (!Get.isRegistered<VetsController>()) {
      Get.put<VetsController>(VetsController(), permanent: true);
    }
    Get.lazyPut<SchedulingController>(() => SchedulingController(), fenix: true);
    Get.lazyPut<ProfileController>(() => ProfileController(), fenix: true);
    if (!Get.isRegistered<ProntuarioController>()) {
      Get.put<ProntuarioController>(ProntuarioController(), permanent: true);
    }
  }
}
