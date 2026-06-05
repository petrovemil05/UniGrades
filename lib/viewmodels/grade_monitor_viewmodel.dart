import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/grade_monitor_service.dart';
import '../services/notification_service.dart';

class GradeMonitorViewModel extends ChangeNotifier {
  bool _isMonitoring = false;

  bool get isMonitoring => _isMonitoring;

  String get toggleLabel => _isMonitoring ? "Спри следенето" : "Следи оценките";

  GradeMonitorViewModel() {
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    _isMonitoring = await FlutterBackgroundService().isRunning();
    notifyListeners();
  }

  Future<void> toggle() async {
    final service = FlutterBackgroundService();
    bool isRunning = await service.isRunning();

    if (isRunning) {
      service.invoke("stopService");
      _isMonitoring = false;
      await NotificationService.cancel(GradeMonitorService.persistentNotifId);
    } else {
      final prefs = await SharedPreferences.getInstance();
      String fnum = prefs.getString("fnum") ?? "";
      String egn = prefs.getString("egn") ?? "";

      if (fnum.isEmpty || egn.isEmpty) return;

      await service.startService();
      _isMonitoring = true;
    }
    notifyListeners();
  }
}
