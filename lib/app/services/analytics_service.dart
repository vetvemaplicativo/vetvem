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
}
