import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:get/get.dart';

/// Wrapper fino sobre o Firebase Analytics. Centraliza os eventos do
/// funil do tutor para manter os nomes consistentes entre as telas.
class AnalyticsService extends GetxService {
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: analytics);

  Future<void> logLogin(String method) =>
      analytics.logLogin(loginMethod: method);

  Future<void> logSignUp(String method) =>
      analytics.logSignUp(signUpMethod: method);

  Future<void> logAppointmentCreated({
    required String vetId,
    required String serviceName,
  }) =>
      analytics.logEvent(name: 'appointment_created', parameters: {
        'vet_id': vetId,
        'service_name': serviceName,
      });

  // ── Funil do tutor: antes do pedido ───────────────────────────────
  Future<void> logViewVetList() => analytics.logEvent(name: 'view_professional_list');

  Future<void> logViewVetProfile(String vetId) => analytics.logEvent(
      name: 'view_professional_profile', parameters: {'vet_id': vetId});

  Future<void> logBookingStarted(String vetId) =>
      analytics.logEvent(name: 'booking_started', parameters: {'vet_id': vetId});

  /// Toque num passo do guia da primeira consulta (pet, address, vet, request).
  Future<void> logGuideTap(String step) =>
      analytics.logEvent(name: 'first_consult_guide_tap', parameters: {'step': step});

  /// Busca vazia para a região do tutor: mostra onde há demanda sem atendimento.
  Future<void> logSearchNoResults(String uf, String city) => analytics.logEvent(
      name: 'search_no_results', parameters: {'uf': uf, 'city': city});

  Future<void> logRegionAction(String action, String uf, String city) =>
      analytics.logEvent(
          name: 'region_empty_action',
          parameters: {'action': action, 'uf': uf, 'city': city});
}
