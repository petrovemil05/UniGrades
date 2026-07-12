import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/fcm_service.dart';
import '../services/grade_monitor_service.dart';
import '../services/notification_service.dart';

class GradeMonitorViewModel extends ChangeNotifier {
  static const String _prefMonitoringKey = 'is_monitoring';
  static const String _prefStatusKey = 'grade_monitor_status';
  static const String statusOff = 'off';
  static const String statusTracking = 'tracking';
  static const String statusChecking = 'checking';
  static const String statusError = 'error';

  bool _isMonitoring = false;
  String _status = statusOff;

  bool get isMonitoring => _isMonitoring;
  String get status => _status;
  String get toggleLabel => _isMonitoring ? 'Спри следенето' : 'Следи оценките';

  GradeMonitorViewModel() {
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    _isMonitoring = prefs.getBool(_prefMonitoringKey) ?? false;
    _status = prefs.getString(_prefStatusKey) ?? (_isMonitoring ? statusTracking : statusOff);
    notifyListeners();
  }

  Future<void> _setStatus(String value) async {
    _status = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefStatusKey, value);
    notifyListeners();
  }

  void setMonitoring(bool value) {
    _isMonitoring = value;
    _status = value ? statusTracking : statusOff;
    notifyListeners();
  }

  Future<void> toggle({String? notificationMode}) async {
    final prefs = await SharedPreferences.getInstance();

    if (_isMonitoring) {
      _isMonitoring = false;
      await _setStatus(statusOff);
      await FcmService.unregister();
      await NotificationService.cancel(GradeMonitorService.persistentNotifId);
      await prefs.setBool(_prefMonitoringKey, false);
      return;
    }

    if (notificationMode != null) {
      await prefs.setString(GradeMonitorService.prefNotificationModeKey, notificationMode);
    }

    _isMonitoring = true;
    await _setStatus(statusChecking);
    await FcmService.register();
    await prefs.setBool(_prefMonitoringKey, true);
    try {
      await FcmService.runCheckNow();
      await _setStatus(statusTracking);
    } catch (_) {
      await _setStatus(statusError);
    }
    notifyListeners();
  }
}