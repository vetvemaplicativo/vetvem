import 'package:get/get.dart';
import '../../../routes/app_routes.dart';
import '../login/login_controller.dart';

/// Reaproveita os fluxos do login (Google/Apple: criação do perfil, bloqueio,
/// termos, celular e retomada do agendamento via `pendingVetId` na Home).
class CreateAccountController extends LoginController {
  /// Cadastro por e-mail: o fluxo atual (Seus dados → endereço → pet).
  void goToEmail() => Get.toNamed(Routes.register);

  /// Quem já tem conta: troca esta tela por Entrar (o voltar leva ao ponto anterior).
  void goToLogin() => Get.offNamed(Routes.login);
}
