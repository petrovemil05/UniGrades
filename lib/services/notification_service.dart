import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;

    // Using '@mipmap/icon' as it is a valid large file in your project
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/icon');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    try {
      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          if (response.actionId == 'check_now') {
            FlutterBackgroundService().invoke('checkNow');
          }
        },
      ).timeout(const Duration(seconds: 3));

      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        debugPrint("Creating notification channels...");
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

        // Adding a basic test channel
        await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
          'test_channel',
          'Тестови известия',
          description: 'Канал за тестване на известия',
          importance: Importance.high,
        ));
      }
      _isInitialized = true;
      debugPrint("NotificationService initialized successfully");
    } catch (e) {
      debugPrint("NotificationService.init error: $e");
    }
  }

  static Future<void> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          await androidPlugin.requestNotificationsPermission();
        }
      } catch (e) {
        debugPrint("Error requesting notification permissions: $e");
      }
    }
  }

  static Future<void> showTestNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'test_channel',
      'Тестови известия',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    await _notificationsPlugin.show(
      id: 999,
      title: 'Тест',
      body: 'Това е тестово известие',
      notificationDetails: const NotificationDetails(android: androidPlatformChannelSpecifics),
    );
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
        AndroidNotificationAction(
          'check_now',
          'Провери сега',
          showsUserInterface: false,
        ),
      ],
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: androidPlatformChannelSpecifics),
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

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: androidPlatformChannelSpecifics),
    );
  }

  static Future<void> cancel(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }
}
