import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/grade_monitor_service.dart';
import '../services/notification_service.dart';
import '../ui/university_picker_page.dart';

class GradeMonitorViewModel extends ChangeNotifier {
  bool _isMonitoring = false;

  bool get isMonitoring => _isMonitoring;

  String get toggleLabel => _isMonitoring ? 'Спри следенето' : 'Следи оценките';

  GradeMonitorViewModel() {
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    _isMonitoring = await FlutterBackgroundService().isRunning();
    notifyListeners();
  }

  Future<void> toggle() async {
    final service   = FlutterBackgroundService();
    bool isRunning  = await service.isRunning();

    if (isRunning) {
      service.invoke('stopService');
      _isMonitoring = false;
      await NotificationService.cancel(GradeMonitorService.persistentNotifId);
    } else {
      final prefs      = await SharedPreferences.getInstance();
      final university = prefs.getString(UniversityPickerPage.prefKey) ?? 'TU';

      // Pick the right credential keys based on university
      final key1 = university == 'TU' ? 'fnum'     : 'username';
      final key2 = university == 'TU' ? 'egn'      : 'password';

      final cred1 = prefs.getString(key1) ?? '';
      final cred2 = prefs.getString(key2) ?? '';

      if (cred1.isEmpty || cred2.isEmpty) return;

      await service.startService();
      _isMonitoring = true;
    }
    notifyListeners();
  }
}