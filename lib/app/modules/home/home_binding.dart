import 'package:get/get.dart';
import 'home_controller.dart';
import '../vets/vets_controller.dart';
import '../scheduling/scheduling_controller.dart';
import '../profile/profile_controller.dart';
import '../prontuario/prontuario_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    // Uma só instância na sessão (Busca e Home): ao entrar na conta a Home é
    // recriada (offAllNamed) e, com lazyPut, a tela ficava presa a dois
    // controladores — filtro "sem efeito", busca em carregamento, endereço
    // novo que não aparecia. A troca de conta é tratada nos controladores.
    if (!Get.isRegistered<VetsController>()) {
      Get.put<VetsController>(VetsController(), permanent: true);
    }
    Get.lazyPut<SchedulingController>(() => SchedulingController(), fenix: true);
    Get.lazyPut<ProfileController>(() => ProfileController(), fenix: true);
    if (!Get.isRegistered<HomeController>()) {
      Get.put<HomeController>(HomeController(), permanent: true);
    } else {
      // Já existe: aplica a aba pedida na navegação (ex.: pagamento → Consultas).
      final args = Get.arguments;
      final home = Get.find<HomeController>();
      home.currentIndex.value =
          (args is Map && args['tab'] is int) ? args['tab'] as int : 0;
    }
    if (!Get.isRegistered<ProntuarioController>()) {
      Get.put<ProntuarioController>(ProntuarioController(), permanent: true);
    }
  }
}
