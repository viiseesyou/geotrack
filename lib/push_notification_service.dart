import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> initialize() async {
    // Запрашиваем разрешение на уведомления
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await _saveToken();
    }

    // Обработка уведомлений когда приложение открыто
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Уведомление получено: ${message.notification?.title}');
    });

    // Обработка когда пользователь нажал на уведомление
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Открыто уведомление: ${message.notification?.title}');
    });
  }

  // Сохраняем FCM токен в Firestore
  static Future<void> _saveToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await _messaging.getToken();
    if (token != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': token,
      });
    }

    // Обновляем токен если он изменился
    _messaging.onTokenRefresh.listen((newToken) async {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'fcmToken': newToken,
        });
      }
    });
  }

  // Отправить уведомление участнику группы через Firestore
  // (Cloud Functions отправит реальный push)
  static Future<void> sendGeozoneAlert({
    required String targetUserId,
    required String personName,
    required String zoneName,
    required bool isEntering,
  }) async {
    final action = isEntering ? 'вошёл(а) в зону' : 'вышел(а) из зоны';
    final emoji = isEntering ? '✅' : '⚠️';

    await _firestore.collection('notifications').add({
      'targetUserId': targetUserId,
      'title': '$emoji GeoTrack',
      'body': '$personName $action "$zoneName"',
      'type': 'geozone',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  // Получить токен текущего пользователя
  static Future<String?> getToken() async {
    return await _messaging.getToken();
  }
}