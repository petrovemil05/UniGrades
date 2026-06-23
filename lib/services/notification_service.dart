import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint('BACKGROUND ACTION: ${response.actionId}');

  final service = FlutterBackgroundService();

  if (response.actionId == 'check_now') {
    service.invoke('checkNow');
  } else if (response.actionId == 'stop_monitoring') {
    service.invoke('stopService');
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/icon');

    final DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    try {
      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          debugPrint('FOREGROUND ACTION: ${response.actionId}');

          final service = FlutterBackgroundService();

          if (response.actionId == 'check_now') {
            service.invoke('checkNow');
          } else if (response.actionId == 'stop_monitoring') {
            service.invoke('stopService');
          }
        },
        onDidReceiveBackgroundNotificationResponse:
        notificationTapBackground,
      ).timeout(const Duration(seconds: 3));

      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
          'grade_monitor_channel',
          'Следене на оценки',
          description: 'Показва текущия статус на следенето',
          importance: Importance.low,
          showBadge: false,
          enableVibration: false,
          playSound: false,
        ));

        await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
          'grade_alert_channel',
          'Нови оценки',
          description: 'Известия за нови оценки',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ));
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint("NotificationService.init error: $e");
    }
  }

  static Future<void> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          await androidPlugin.requestNotificationsPermission();
        }
      } else if (Platform.isIOS) {
        final iosPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        if (iosPlugin != null) {
          await iosPlugin.requestPermissions(alert: true, badge: true, sound: true);
        }
      }
    } catch (e) {
      debugPrint("Error requesting notification permissions: $e");
    }
  }

  static Future<void> showPersistent(int id, String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'grade_monitor_channel',
      'Следене на оценки',
      channelDescription: 'Показва текущия статус на следенето',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: true,
      actions: [
        // AndroidNotificationAction(
        //   'check_now',
        //   'Провери сега',
        //   showsUserInterface: true,
        // ),
        // AndroidNotificationAction(
        //   'stop_monitoring',
        //   'Спри',
        //   showsUserInterface: true,
        // ),
      ],
    );

    const DarwinNotificationDetails iOSPersistentDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPersistentDetails,
      ),
    );
  }

  static Future<void> showAlert(int id, String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'grade_alert_channel',
      'Нови оценки',
      channelDescription: 'Известия за нови оценки',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iOSAlertDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSAlertDetails,
      ),
    );
  }

  static Future<void> cancel(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }
}
