import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'grade_monitor_service.dart'; // your existing checker

// Runs when app is terminated — FCM wakes it up silently
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (message.data['type'] != 'check_grades') return;

  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();

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

class FcmService {
  static const String _serverUrl = 'https://uni-grades-server.onrender.com';
  static const String _prefFcmTokenKey = 'fcm_token';

  static final _localNotif = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Local notification channel (for when app is in foreground)
    const channel = AndroidNotificationChannel(
      'grade_alerts', 'Нови оценки',
      description: 'Известия при нова оценка',
      importance: Importance.high,
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _localNotif.initialize(settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_icon_circle_nobg'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ));

    // Handle wake-up when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;

      // For display notifications (from Firebase console)
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

      // For silent data messages (from your server ping)
      if (message.data['type'] == 'check_grades') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();

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
    });

    // Handle wake-up when app is in background (but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((_) {});

    await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );

    // Token refresh — re-register with server automatically
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await _sendRegistration(newToken);
    });
  }

  // Call on login — only sends the FCM token, nothing else
  static Future<void> register() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefFcmTokenKey, token);
    print('FCM Token: $token');
    await _sendRegistration(token);
  }

  static Future<void> runCheckNow() async {
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

  static Future<void> _sendRegistration(String token) async {
    await http.post(
      Uri.parse('$_serverUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fcmToken': token, 'platform': "android"}),
    );
  }

  // Call on logout
  static Future<void> unregister() async {
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