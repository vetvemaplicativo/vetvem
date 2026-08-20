import 'package:get/get.dart';
import '../../routes/app_routes.dart';
import '../profile/profile_controller.dart';

class RatingController extends GetxController {
  late final String consultationId;
  late final String vetName;
  late final String petName;
  late final String date;
  late final String specialty;

  final selectedStars = 0.obs;
  final isSubmitted = false.obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    consultationId = args['consultationId'] ?? '';
    vetName        = args['vetName'] ?? 'Veterinário';
    petName        = args['petName'] ?? 'Pet';
    date           = args['date'] ?? '';
    specialty      = args['specialty'] ?? '';
  }

  void selectStars(int stars) => selectedStars.value = stars;

  Future<void> submit(String comment) async {
    if (selectedStars.value == 0) {
      Get.snackbar('Atenção', 'Selecione pelo menos 1 estrela',
          snackPosition: SnackPosition.TOP);
      return;
    }
    isLoading.value = true;
    try {
      await Get.find<ProfileController>()
          .rateConsultation(consultationId, selectedStars.value, comment);
      isSubmitted.value = true;
    } catch (_) {
      Get.snackbar('Erro', 'Não foi possível enviar a avaliação. Tente novamente.',
          snackPosition: SnackPosition.TOP);
    } finally {
      isLoading.value = false;
    }
  }

  // Após sucesso volta para a lista de consultas
  void goBack() => Get.until((route) => route.settings.name == Routes.home);
}
