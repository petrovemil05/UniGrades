import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/grade_monitor_service.dart';
import '../services/notification_service.dart';

class GradeMonitorViewModel extends ChangeNotifier {
  bool _isMonitoring = false;
  GradeMonitorService? _service;
  Timer? _timer;

  bool get isMonitoring => _isMonitoring;

  String get toggleLabel => _isMonitoring ? "Спри следенето" : "Следи оценките";

  Future<void> toggle() async {
    if (_isMonitoring) {
      await stopService();
      _isMonitoring = false;
    } else {
      bool started = await startService();
      if (started) {
        _isMonitoring = true;
      }
    }
    notifyListeners();
  }

  Future<bool> startService() async {
    final prefs = await SharedPreferences.getInstance();
    String fnum = prefs.getString("fnum") ?? "";
    String egn = prefs.getString("egn") ?? "";

    if (fnum.isEmpty || egn.isEmpty) {
      return false;
    }

    _service = GradeMonitorService(fnum: fnum, egn: egn);

    // 1. Initial check (immediate)
    await _service?.checkOnce();

    // 2. Schedule the next check at the next :00 or :30 mark
    Duration delay = _service!.timeUntilNextHalfHour();
    _timer = Timer(delay, () {
      _service?.checkOnce();
      
      // 3. From then on, check every 30 minutes
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(minutes: 30), (timer) {
        _service?.checkOnce();
      });
    });

    return true;
  }

  Future<void> stopService() async {
    _timer?.cancel();
    _timer = null;
    _service = null;
    await NotificationService.cancel(GradeMonitorService.persistentNotifId);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
