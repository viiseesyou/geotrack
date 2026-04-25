import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const initSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(iOS: initSettingsIOS);

    await _notifications.initialize(initSettings);

    // Запрашиваем разрешение на iOS
    await _notifications
        .resolvePlatformSpecificImplementation
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> showGeozoneNotification({
    required String personName,
    required String zoneName,
    required bool isEntering,
  }) async {
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(iOS: iosDetails);

    final action = isEntering ? 'вошёл(а) в зону' : 'вышел(а) из зоны';
    final emoji = isEntering ? '✅' : '⚠️';

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '$emoji GeoTrack',
      '$personName $action "$zoneName"',
      details,
    );
  }

  static Future<void> showLocationUpdateNotification(String name) async {
    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: true,
      presentSound: false,
    );

    const details = NotificationDetails(iOS: iosDetails);

    await _notifications.show(
      1,
      'GeoTrack активен',
      'Отслеживание геолокации включено',
      details,
    );
  }
}