import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'grade_monitor_service.dart';
import 'notification_service.dart';
import '../ui/university_picker_page.dart';

class BackgroundService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'grade_monitor_channel',
        initialNotificationTitle: 'Следене на оценки',
        initialNotificationContent: 'Стартиране...',
        foregroundServiceNotificationId: GradeMonitorService.persistentNotifId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: (service) => true,
      ),
    );
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  bool isRunning = true;

  void updateStatus(String title, String body) {
    NotificationService.showPersistent(
      GradeMonitorService.persistentNotifId,
      title,
      body,
    );
  }

  try {
    await NotificationService.init().timeout(
      const Duration(seconds: 5),
      onTimeout: () => debugPrint('Notification init timeout in background'),
    );

    final prefs      = await SharedPreferences.getInstance();
    final university = prefs.getString(UniversityPickerPage.prefKey) ?? 'TU';

    // Pick credential keys based on university
    final key1 = university == 'TU' ? 'fnum'     : 'username';
    final key2 = university == 'TU' ? 'egn'      : 'password';

    final cred1 = prefs.getString(key1) ?? '';
    final cred2 = prefs.getString(key2) ?? '';

    if (cred1.isEmpty || cred2.isEmpty) {
      updateStatus('Грешка', 'Липсват данни за вход.');
      service.stopSelf();
      return;
    }

    service.on('stopService').listen((event) {
      isRunning = false;
      service.stopSelf();
      NotificationService.cancel(GradeMonitorService.persistentNotifId);
    });

    final monitor = GradeMonitorService(
      fnum: cred1,
      egn:  cred2,
      onStatusUpdate: (title, body) => updateStatus(title, body),
    );

    service.on('checkNow').listen((event) async {
      await monitor.checkOnce();
    });

    // Initial check
    await monitor.checkOnce();

    // Monitoring loop
    while (isRunning) {
      try {
        final prefs2 = await SharedPreferences.getInstance();
        final int intervalMinutes = prefs2.getInt(GradeMonitorService.prefIntervalKey)
            ?? GradeMonitorService.defaultIntervalMinutes;

        Duration delay = monitor.timeUntilNextCheck(intervalMinutes);
        debugPrint('Next automatic check in ${delay.inMinutes} minutes');

        await Future.delayed(delay);

        if (!isRunning) break;

        await monitor.checkOnce();
      } catch (e) {
        debugPrint('Loop error: $e');
        await Future.delayed(const Duration(minutes: 1));
      }
    }
  } catch (e) {
    updateStatus('Грешка при работа', e.toString());
  }
}