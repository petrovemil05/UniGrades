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
        initialNotificationTitle: 'e-student Monitor',
        initialNotificationContent: 'Стартиране на услугата...',
        foregroundServiceNotificationId: GradeMonitorService.persistentNotifId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: (service) => true,
      ),
    );
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    debugPrint("BackgroundService.onStart triggered");

    void updateStatus(String title, String body) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: title,
          content: body,
        );
      }
    }

    try {
      // First, establish a stable state
      updateStatus("e-student Monitor", "Зареждане...");

      // Init notifications with timeout to prevent hang
      await NotificationService.init().timeout(
        const Duration(seconds: 5),
        onTimeout: () => debugPrint("Notification init timed out in background"),
      );

      final prefs = await SharedPreferences.getInstance();
      String fnum = prefs.getString("fnum") ?? "";
      String egn = prefs.getString("egn") ?? "";

      if (fnum.isEmpty || egn.isEmpty) {
        updateStatus("e-student Monitor", "Грешка: Няма данни за вход.");
        await Future.delayed(const Duration(seconds: 5));
        service.stopSelf();
        return;
      }

      service.on('stopService').listen((event) {
        service.stopSelf();
      });

      final monitor = GradeMonitorService(
        fnum: fnum,
        egn: egn,
        onStatusUpdate: (title, body) => updateStatus(title, body),
      );

      service.on('checkNow').listen((event) async {
        debugPrint("Manual check triggered via notification");
        await monitor.checkOnce();
      });

      // Perform initial check
      await monitor.checkOnce();

      // Setup periodic checks at round hours
      void scheduleNext() {
        Duration delay = monitor.timeUntilNextHalfHour();
        debugPrint("Next check scheduled in ${delay.inMinutes} minutes");
        Timer(delay, () async {
          await monitor.checkOnce();
          scheduleNext();
        });
      }

      scheduleNext();

    } catch (e, stack) {
      debugPrint("Kriticheska greshka v background service: $e");
      debugPrint(stack.toString());
      updateStatus("e-student Monitor", "Грешка при работа: $e");
    }
  }
}
