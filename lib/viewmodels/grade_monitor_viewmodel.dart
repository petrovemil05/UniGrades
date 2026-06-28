import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/fcm_service.dart';

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

  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isMonitoring) {
      await FcmService.unregister();
      await prefs.setBool(_prefMonitoringKey, false);
      _isMonitoring = false;
    } else {
      await FcmService.register();
      await prefs.setBool(_prefMonitoringKey, true);
      _isMonitoring = true;
    }
    notifyListeners();
  }
}