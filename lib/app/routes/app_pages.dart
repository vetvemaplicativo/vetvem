import 'package:get/get.dart';
import '../modules/splash/splash_binding.dart';
import '../modules/splash/splash_view.dart';
import '../modules/auth/login/login_binding.dart';
import '../modules/auth/login/login_view.dart';
import '../modules/auth/register/register_binding.dart';
import '../modules/auth/register/register_view.dart';
import '../modules/home/home_binding.dart';
import '../modules/home/home_view.dart';
import '../modules/vets/vets_binding.dart';
import '../modules/vets/vets_view.dart';
import '../modules/vets/vet_detail_view.dart';
import '../modules/scheduling/scheduling_binding.dart';
import '../modules/scheduling/scheduling_view.dart';
import '../modules/payment/payment_binding.dart';
import '../modules/payment/payment_view.dart';
import '../modules/profile/profile_binding.dart';
import '../modules/profile/profile_view.dart';
import '../modules/rating/rating_binding.dart';
import '../modules/rating/rating_view.dart';
import '../modules/consultas/consulta_detail_view.dart';
import '../modules/prontuario/prontuario_view.dart';
import '../modules/service_area/service_area_binding.dart';
import '../modules/service_area/service_area_view.dart';
import 'app_routes.dart';

class AppPages {
  static const initial = Routes.splash;

  static final routes = [
    GetPage(
      name: Routes.splash,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: Routes.login,
      page: () => const LoginView(),
      binding: LoginBinding(),
    ),
    GetPage(
      name: Routes.register,
      page: () => const RegisterView(),
      binding: RegisterBinding(),
    ),
    GetPage(
      name: Routes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: Routes.vets,
      page: () => const VetsView(),
      binding: VetsBinding(),
    ),
    GetPage(
      name: Routes.vetDetail,
      page: () => const VetDetailView(),
      binding: VetsBinding(),
    ),
    GetPage(
      name: Routes.scheduling,
      page: () => const SchedulingView(),
      binding: SchedulingBinding(),
    ),
    GetPage(
      name: Routes.payment,
      page: () => const PaymentView(),
      binding: PaymentBinding(),
    ),
    GetPage(
      name: Routes.profile,
      page: () => const ProfileView(),
      binding: ProfileBinding(),
    ),
    GetPage(
      name: Routes.rating,
      page: () => const RatingView(),
      binding: RatingBinding(),
    ),
    GetPage(
      name: Routes.consultaDetail,
      page: () => const ConsultaDetailView(),
    ),
    GetPage(
      name: Routes.prontuario,
      page: () => const ProntuarioView(),
    ),
    GetPage(
      name: Routes.serviceArea,
      page: () => const ServiceAreaView(),
      binding: ServiceAreaBinding(),
    ),
  ];
}
