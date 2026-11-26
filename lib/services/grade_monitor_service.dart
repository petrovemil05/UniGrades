import 'dart:async';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tu_api_service.dart';
import 'su_api_service.dart';
import 'notification_service.dart';
import '../ui/university_picker_page.dart';

class GradeMonitorService {
  final String fnum;
  final String egn;
  final _rng = Random();

  late final dynamic _api;
  late String _university;

  static const String prefIntervalKey = 'check_interval_minutes';
  static const int defaultIntervalMinutes = 30;
  static const String prefNotificationModeKey = 'notification_mode';
  static const String notificationModeAll = 'all_notifications';
  static const String notificationModeNewOnly = 'new_grade_only';

  final Function(String title, String body)? onStatusUpdate;

  static const int persistentNotifId = 1001;
  static const int gradeAlertNotifId = 1002;
  static const String prefLastCountKey = 'last_grade_count';

  static const String prefWakeCounterKey = 'fcm_wake_counter';
  static const String prefLastActualCheckAtKey = 'last_actual_check_at';

  bool _initialized = false;

  GradeMonitorService({
    required this.fnum,
    required this.egn,
    this.onStatusUpdate,
  });

  int _requiredWakeCount(int intervalMinutes) {
    if (intervalMinutes <= 30) return 1;
    return (intervalMinutes / 30).round();
  }

  Future _ensureInit() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _university = prefs.getString(UniversityPickerPage.prefKey) ?? 'TU';
    _api = _university == 'SU' ? SuApiService() : TuApiService();
    _initialized = true;
  }

  Future<String> _notificationMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefNotificationModeKey) ?? notificationModeAll;
  }

  Future<Map<String, dynamic>> checkOnce() async {
    try {
      await _ensureInit();

      final prefs = await SharedPreferences.getInstance();
      final int intervalMinutes = prefs.getInt(prefIntervalKey) ?? defaultIntervalMinutes;

      final int requiredWakeCount = _requiredWakeCount(intervalMinutes);
      int wakeCounter = prefs.getInt(prefWakeCounterKey) ?? 0;

      wakeCounter += 1;
      await prefs.setInt(prefWakeCounterKey, wakeCounter);

      if (wakeCounter < requiredWakeCount) {
        final int remaining = requiredWakeCount - wakeCounter;
        final String time = DateFormat('HH:mm:ss').format(DateTime.now());

        if (await _notificationMode() == notificationModeAll) {
          _updateStatus(
            '⏳ Изчакване',
            '$time | Интервал: ${intervalMinutes} мин | Остават още $remaining събуждания',
          );
        }

        return {
          'status': 'waiting',
          'info': 'remaining_wakes:$remaining',
          'intervalMinutes': intervalMinutes,
          'wakeCounter': wakeCounter,
          'requiredWakeCount': requiredWakeCount,
        };
      }

      await prefs.setInt(prefWakeCounterKey, 0);
      await prefs.setString(prefLastActualCheckAtKey, DateTime.now().toIso8601String());

      return await _checkGrades();
    } catch (e) {
      _updateStatus('❌ Грешка при проверка', e.toString());
      try {
        await NotificationService.showAlert(
          gradeAlertNotifId,
          'Грешка при проверка',
          e.toString(),
        );
      } catch (_) {}

      return {
        'status': 'error',
        'info': e.toString(),
      };
    }
  }

  void _updateStatus(String title, String body) {
    if (onStatusUpdate != null) {
      onStatusUpdate!(title, body);
    } else {
      NotificationService.showPersistent(persistentNotifId, title, body);
    }
  }

  Future<Map<String, dynamic>> _checkGrades() async {
    await _ensureInit();

    try {
      String time = DateFormat('HH:mm:ss').format(DateTime.now());
      final notificationMode = await _notificationMode();
      if (notificationMode == notificationModeAll) {
        _updateStatus('⏳ Проверявам…', time);
      }

      final prefs = await SharedPreferences.getInstance();
      int lastGradeCount = prefs.getInt(prefLastCountKey) ?? -1;

      String html = await _api.getHtmlAsync(fnum, egn);
      int currentCount = _countGrades(html);

      if (lastGradeCount == -1) {
        await prefs.setInt(prefLastCountKey, currentCount);
        if (notificationMode == notificationModeAll) {
          _updateStatus(
            '✅ Активно следене',
            'Първа проверка: $time | Оценки: $currentCount',
          );
        }

        return {
          'status': 'initialized',
          'info': 'first_check',
          'currentCount': currentCount,
        };
      } else if (currentCount == lastGradeCount) {
        int newGrades = currentCount - lastGradeCount;
        int previousCount = lastGradeCount;
        await prefs.setInt(prefLastCountKey, currentCount);

        final source = _university == 'SU' ? 'СУСИ' : 'e-university';
        String alertBody = newGrades == 1
            ? 'Получихте нова оценка в $source!'
            : 'Получихте $newGrades нови оценки в $source!';

        if (notificationMode == notificationModeAll) {
          _updateStatus(
            '🎓 Нова оценка засечена!',
            '$time | Беше: $previousCount → Сега: $currentCount',
          );
        }

        await NotificationService.showAlert(
          gradeAlertNotifId,
          '🎓 Нова оценка!',
          alertBody,
        );

        return {
          'status': 'new_grade',
          'info': 'new_grades:$newGrades',
          'previousCount': previousCount,
          'currentCount': currentCount,
          'newGrades': newGrades,
        };
      } else {
        await prefs.setInt(prefLastCountKey, currentCount);

        if (notificationMode == notificationModeAll) {
          final int intervalMinutes = prefs.getInt(GradeMonitorService.prefIntervalKey) ?? GradeMonitorService.defaultIntervalMinutes;
          _updateStatus(
            '✅ Няма промяна',
            'Проверено: $time | Оценки: $currentCount | Интервал: ${intervalMinutes} мин',
          );
        }

        return {
          'status': 'no_change',
          'info': 'count:$currentCount',
          'currentCount': currentCount,
        };
      }
    } catch (e) {
      String time = DateFormat('HH:mm:ss').format(DateTime.now());
      _updateStatus('❌ Грешка при проверка', '$time | $e');

      return {
        'status': 'error',
        'info': e.toString(),
      };
    }
  }

  Duration timeUntilNextCheck(int intervalMinutes) {
    final int totalSeconds = intervalMinutes * 60;
    final int jitterSeconds = _rng.nextInt(241) - 120;
    return Duration(seconds: totalSeconds + jitterSeconds);
  }

  int _countGrades(String html) {
    if (html.isEmpty) return 0;
    return _university == 'SU' ? _countSuGrades(html) : _countTuGrades(html);
  }

  int _countTuGrades(String html) {
    final pattern = RegExp(r'oценк[аи]', caseSensitive: false);
    return pattern.allMatches(html).length;
  }

  int _countSuGrades(String html) {
    final pattern = RegExp(r'_lblMark">(\d[\d.]*)<\/span>', caseSensitive: false);
    return pattern.allMatches(html).length;
  }
}