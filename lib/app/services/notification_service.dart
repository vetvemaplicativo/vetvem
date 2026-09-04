import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _fln = FlutterLocalNotificationsPlugin();
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static StreamSubscription? _sub;

  static const _channel = AndroidNotificationChannel(
    'vetvem_channel_v2',
    'VetVem',
    description: 'Notificações do VetVem',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> init() async {
    // Inicializa flutter_local_notifications
    await _fln
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _fln.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // Pede permissão (Android 13+ e iOS)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Mostra o banner/som quando o app está em primeiro plano no iOS
    // (por padrão o iOS silencia notificações com o app aberto).
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Salva token FCM no Firestore
    await _saveToken();

    // Escuta mudanças de token
    FirebaseMessaging.instance.onTokenRefresh.listen(_updateToken);

    // Em foreground quem exibe é o listener do Firestore (abaixo);
    // o push FCM (enviado pela function sendPush) cobre background/app fechado.
    _listenFirestoreNotifications();
  }

  static Future<void> _saveToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await _firestore.collection('users').doc(uid).update({'fcmToken': token});
  }

  static Future<void> _updateToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).update({'fcmToken': token});
  }

  // Escuta coleção notifications/{uid} no Firestore
  static void _listenFirestoreNotifications() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _sub?.cancel();
    _sub = _firestore
        .collection('notifications')
        .doc(uid)
        .collection('pending')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final d = change.doc.data() ?? {};
          // pushed=true: o push FCM já exibiu esta notificação (app fechado).
          // Freshness: fallback para docs antigos sem push (ex.: sem token).
          final ts = d['createdAt'];
          final created = ts is Timestamp ? ts.toDate() : null;
          final fresh = created == null ||
              DateTime.now().difference(created).inMinutes < 3;
          // Só exibe com o app em primeiro plano — em background/fechado o
          // push FCM já aparece na bandeja (evita duplicata na bandeja).
          final foreground = WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed;
          if (foreground && d['pushed'] != true && fresh) {
            _show(
              title: d['title'] as String? ?? 'VetVem',
              body: d['body'] as String? ?? '',
            );
          }
          // Marca como lida
          change.doc.reference.update({'read': true});
        }
      }
    });
  }

  static Future<void> _show({required String title, required String body}) async {
    await _fln.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.max,
          color: const Color(0xFFFF6B35),
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
          ticker: title,
          visibility: NotificationVisibility.public,
        ),
      ),
    );
  }

  // Envia notificação para outro usuário via Firestore
  static Future<void> sendTo({
    required String toUid,
    required String title,
    required String body,
    String? tipo,
    String? appointmentId,
  }) async {
    await _firestore
        .collection('notifications')
        .doc(toUid)
        .collection('pending')
        .add({
      'title': title,
      'body': body,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      if (tipo != null) 'tipo': tipo,
      if (appointmentId != null) 'appointmentId': appointmentId,
    });
  }

  static void dispose() {
    _sub?.cancel();
  }
}
