import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/fcm_service.dart';
import '../services/grade_monitor_service.dart';
import '../services/notification_service.dart';

class GradeMonitorViewModel extends ChangeNotifier {
  static const String _prefMonitoringKey = 'is_monitoring';

  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;
  String get toggleLabel => _isMonitoring ? 'Спри следенето' : 'Следи оценките';

  GradeMonitorViewModel() {
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    _isMonitoring = prefs.getBool(_prefMonitoringKey) ?? false;
    notifyListeners();
  }

  void setMonitoring(bool value) {
    _isMonitoring = value;
    notifyListeners();
  }

  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();

    if (_isMonitoring) {
      _isMonitoring = false;
      notifyListeners();
      await FcmService.unregister();
      await NotificationService.cancel(GradeMonitorService.persistentNotifId);
      await prefs.setBool(_prefMonitoringKey, false);
    } else {
      _isMonitoring = true;
      notifyListeners();
      await FcmService.register();
      await prefs.setBool(_prefMonitoringKey, true);
      await FcmService.runCheckNow();
    }
    notifyListeners();
  }
}