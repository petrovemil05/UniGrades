import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'grade_monitor_service.dart';
import 'notification_service.dart';

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

  // Use NotificationService directly to ensure buttons (actions) are preserved
  void updateStatus(String title, String body) {
    NotificationService.showPersistent(
      GradeMonitorService.persistentNotifId,
      title,
      body,
    );
  }

  try {
    // 1. Initial setup
    await NotificationService.init().timeout(
      const Duration(seconds: 5),
      onTimeout: () => debugPrint("Notification init timeout in background"),
    );

    final prefs = await SharedPreferences.getInstance();
    String fnum = prefs.getString("fnum") ?? "";
    String egn = prefs.getString("egn") ?? "";

    if (fnum.isEmpty || egn.isEmpty) {
      updateStatus("Грешка", "Липсват данни за вход.");
      service.stopSelf();
      return;
    }

    service.on('stopService').listen((event) {
      isRunning = false;
      service.stopSelf();
      NotificationService.cancel(GradeMonitorService.persistentNotifId);
    });

    final monitor = GradeMonitorService(
      fnum: fnum,
      egn: egn,
      onStatusUpdate: (title, body) => updateStatus(title, body),
    );

    service.on('checkNow').listen((event) async {
      await monitor.checkOnce();
    });

    // 1. Initial check
    await monitor.checkOnce();

    // 2. Monitoring loop
    while (isRunning) {
      try {
        Duration delay = monitor.timeUntilNextHalfHour();
        debugPrint("Next automatic check in ${delay.inMinutes} minutes");
        
        // Wait until next interval (00 or 30)
        await Future.delayed(delay);

        if (!isRunning) break;

        // Perform check
        await monitor.checkOnce();
      } catch (e) {
        debugPrint("Loop error: $e");
        await Future.delayed(const Duration(minutes: 1));
      }
    }

  } catch (e) {
    updateStatus("Грешка при работа", e.toString());
  }
}
