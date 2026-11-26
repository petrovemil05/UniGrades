import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'grade_monitor_service.dart';
import 'web_credentials_store.dart';
import 'web_message_listener_factory/web_message_listener_factory.dart';

@pragma('vm:entry-point')
Future _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FcmService.handleCheckGradesMessage(message);
}

class FcmService {
  static const String _serverUrl = 'https://unigrades.bgsrv.eu';
  static const String _prefFcmTokenKey = 'fcm_token';
  static const String _webVapidKey =
      'BLGIb01So6eXzcW0UFYYjOH8s8NVQwzDkTLgK6-Nkz5qlSUJJXAySqa-8lx1zfMN628Txi8wBHivOxG3BXklAl4';

  static final _localNotif = FlutterLocalNotificationsPlugin();
  static bool _webListenersAttached = false;
  static String? _lastRegisteredToken;

  static Future _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefFcmTokenKey, token);
    if (kIsWeb) {
      await WebCredentialsStore.saveValue('fcm_token', token);
    }
  }

  static Future init() async {
    try {
      if (kIsWeb) {
        final messaging = FirebaseMessaging.instance;

        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        debugPrint('Notification permission: ${settings.authorizationStatus}');

        if (settings.authorizationStatus != AuthorizationStatus.authorized) {
          return;
        }

        final token = await messaging.getToken(vapidKey: _webVapidKey);

        if (token != null) {
          await _saveToken(token);
          await _sendRegistration(token);
        }

        if (_webListenersAttached) return;
        _webListenersAttached = true;

        messaging.onTokenRefresh.listen((newToken) async {
          await _saveToken(newToken);
          await _sendRegistration(newToken);
        });

        setupWebMessageListener((jobId, data) async {
          debugPrint('Received web background check trigger: $jobId');
          await handleCheckGradesMessage(RemoteMessage(
            data: data.map((key, value) => MapEntry(key, value.toString())),
          ));
        });

        // Runs only while the page is focused; the service worker covers the rest.
        FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
          await handleCheckGradesMessage(message);
        });

        return;
      }

      if (!kIsWeb) {
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
    } catch (e) {
      debugPrint('FcmService init error: $e');
    }
  }

  static Future register() async {
    try {
      final token = kIsWeb
          ? await FirebaseMessaging.instance.getToken(vapidKey: _webVapidKey)
          : await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await _saveToken(token);

      await _sendRegistration(token);
    } catch (e) {
      debugPrint('FcmService register error: $e');
    }
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
    // Skip if this exact token was already sent (or is being sent) in this session.
    if (_lastRegisteredToken == token) return;
    _lastRegisteredToken = token;

    final now = DateTime.now().toUtc();
    final formattedDate = "${now.year.toString().padLeft(4, '0')}-"
        "${now.month.toString().padLeft(2, '0')}-"
        "${now.day.toString().padLeft(2, '0')} "
        "${now.hour.toString().padLeft(2, '0')}:"
        "${now.minute.toString().padLeft(2, '0')}:"
        "${now.second.toString().padLeft(2, '0')}."
        "${now.millisecond.toString().padLeft(3, '0')}";

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fcmToken': token,
          'platform': kIsWeb ? 'web' : 'android',
          'registeredAt': formattedDate,
          'registered_at': formattedDate,
        }),
      );

      // Allow a retry later if the server rejected it.
      if (response.statusCode >= 400) {
        _lastRegisteredToken = null;
      }
    } catch (_) {
      _lastRegisteredToken = null;
    }
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
    _lastRegisteredToken = null;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_prefFcmTokenKey);

    if (kIsWeb) {
      try {
        await WebCredentialsStore.clear();
      } catch (_) {}
    }

    if (token == null) return;

    try {
      await http.post(
        Uri.parse('$_serverUrl/unregister'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fcmToken': token}),
      );
    } catch (_) {}

    await prefs.remove(_prefFcmTokenKey);
  }
}