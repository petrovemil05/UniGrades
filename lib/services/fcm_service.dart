import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'grade_monitor_service.dart';

@pragma('vm:entry-point')
Future _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FcmService.handleCheckGradesMessage(message);
}

class FcmService {
  static const String _serverUrl = 'https://uni-grades-server.onrender.com';
  static const String _prefFcmTokenKey = 'fcm_token';

  static final _localNotif = FlutterLocalNotificationsPlugin();

  static Future init() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    const channel = AndroidNotificationChannel(
      'grade_alerts',
      'Нови оценки',
      description: 'Известия при нова оценка',
      importance: Importance.high,
    );

    await _localNotif
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _localNotif.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_icon_circle_nobg'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;

      if (notification != null) {
        await _localNotif.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'grade_alerts',
              'Нови оценки',
              channelDescription: 'Известия при нова оценка',
              importance: Importance.high,
              priority: Priority.high,
              icon: 'ic_icon_circle_nobg',
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
        );
      }

      await handleCheckGradesMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((_) {});

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefFcmTokenKey, newToken);
      await _sendRegistration(newToken);
    });
  }

  static Future register() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefFcmTokenKey, token);

    print('FCM Token: $token');
    await _sendRegistration(token);
  }

  static Future runCheckNow() async {
    final prefs = await SharedPreferences.getInstance();
    final university = prefs.getString('university') ?? 'TU';

    final key1 = university == 'TU' ? 'fnum' : 'username';
    final key2 = university == 'TU' ? 'egn' : 'password';

    final user1 = prefs.getString(key1) ?? '';
    final user2 = prefs.getString(key2) ?? '';

    if (user1.isEmpty || user2.isEmpty) return;

    final monitor = GradeMonitorService(
      fnum: user1,
      egn: user2,
    );

    await monitor.checkOnce();
  }

  static Future handleCheckGradesMessage(RemoteMessage message) async {
    if (message.data['type'] != 'check_grades') return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final university = prefs.getString('university') ?? 'TU';
    final key1 = university == 'TU' ? 'fnum' : 'username';
    final key2 = university == 'TU' ? 'egn' : 'password';

    final user1 = prefs.getString(key1) ?? '';
    final user2 = prefs.getString(key2) ?? '';
    final jobId = message.data['jobId'];
    final fcmToken = prefs.getString(_prefFcmTokenKey);

    if (jobId == null || jobId.toString().isEmpty) {
      return;
    }

    if (fcmToken == null || fcmToken.isEmpty) {
      return;
    }

    if (user1.isEmpty || user2.isEmpty) {
      await _sendAck(
        jobId: jobId.toString(),
        fcmToken: fcmToken,
        status: 'skipped',
        info: 'missing_credentials',
      );
      return;
    }

    final monitor = GradeMonitorService(
      fnum: user1,
      egn: user2,
    );

    try {
      final result = await monitor.checkOnce();

      await _sendAck(
        jobId: jobId.toString(),
        fcmToken: fcmToken,
        status: result['status']?.toString() ?? 'ok',
        info: result['info']?.toString() ?? 'done',
      );
    } catch (e) {
      await _sendAck(
        jobId: jobId.toString(),
        fcmToken: fcmToken,
        status: 'error',
        info: e.toString(),
      );
    }
  }

  static Future _sendRegistration(String token) async {
    await http.post(
      Uri.parse('$_serverUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fcmToken': token,
        'platform': 'android',
      }),
    );
  }

  static Future _sendAck({
    required String jobId,
    required String fcmToken,
    required String status,
    required String info,
  }) async {
    try {
      await http.post(
        Uri.parse('$_serverUrl/ack'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jobId': jobId,
          'fcmToken': fcmToken,
          'status': status,
          'info': info,
        }),
      );
    } catch (_) {}
  }

  static Future unregister() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_prefFcmTokenKey);
    if (token == null) return;

    await http.post(
      Uri.parse('$_serverUrl/unregister'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fcmToken': token}),
    );

    await prefs.remove(_prefFcmTokenKey);
  }
}