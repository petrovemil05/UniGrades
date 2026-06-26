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

  final Function(String title, String body)? onStatusUpdate;

  static const int persistentNotifId    = 1001;
  static const int gradeAlertNotifId    = 1002;
  static const String prefLastCountKey = "last_grade_count";

  bool _initialized = false;

  GradeMonitorService({
    required this.fnum,
    required this.egn,
    this.onStatusUpdate,
  });

  Future<void> _ensureInit() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _university = prefs.getString(UniversityPickerPage.prefKey) ?? 'TU';
    _api = _university == 'SU' ? SuApiService() : TuApiService();
    _initialized = true;
  }

  Future<void> checkOnce() async {
    try {
      await _checkGrades();
    } catch (e) {
      _updateStatus('❌ Грешка при проверка', e.toString());
      try {
        NotificationService.showAlert(gradeAlertNotifId, 'Грешка при проверка', e.toString());
      } catch (_) {}
    }
  }

  void _updateStatus(String title, String body) {
    if (onStatusUpdate != null) {
      onStatusUpdate!(title, body);
    } else {
      NotificationService.showPersistent(persistentNotifId, title, body);
    }
  }

  Future<void> _checkGrades() async {
    await _ensureInit();

    try {
      String time = DateFormat('HH:mm:ss').format(DateTime.now());
      _updateStatus('⏳ Проверявам…', time);

      final prefs = await SharedPreferences.getInstance();
      int lastGradeCount = prefs.getInt(prefLastCountKey) ?? -1;

      String html = await _api.getHtmlAsync(fnum, egn);
      int currentCount = _countGrades(html);

      if (lastGradeCount == -1) {
        await prefs.setInt(prefLastCountKey, currentCount);
        _updateStatus(
          '✅ Активно следене',
          'Първа проверка: $time | Оценки: $currentCount',
        );
      } else if (currentCount > lastGradeCount) {
        int newGrades     = currentCount - lastGradeCount;
        int previousCount = lastGradeCount;
        await prefs.setInt(prefLastCountKey, currentCount);

        final source = _university == 'SU' ? 'СУСИ' : 'e-university';
        String alertBody = newGrades == 1
            ? 'Получихте нова оценка в $source!'
            : 'Получихте $newGrades нови оценки в $source!';

        _updateStatus(
          '🎓 Нова оценка засечена!',
          '$time | Беше: $previousCount → Сега: $currentCount',
        );

        try {
          NotificationService.showAlert(gradeAlertNotifId, '🎓 Нова оценка!', alertBody);
        } catch (_) {}
      } else {
        await prefs.setInt(prefLastCountKey, currentCount);

        final int intervalMinutes = prefs.getInt(GradeMonitorService.prefIntervalKey)
            ?? GradeMonitorService.defaultIntervalMinutes;

        Duration next = timeUntilNextCheck(intervalMinutes);
        String nextTime = DateFormat('HH:mm').format(DateTime.now().add(next));

        _updateStatus(
          '✅ Няма промяна',
          'Проверено: $time | Оценки: $currentCount | Следваща: $nextTime',
        );
      }
    } catch (e) {
      String time = DateFormat('HH:mm:ss').format(DateTime.now());
      _updateStatus('❌ Грешка при проверка', '$time | $e');
    }
  }

  Duration timeUntilNextCheck(int intervalMinutes) {
    const int baseSeconds = 0;
    final int totalSeconds = intervalMinutes * 60;
    final int jitterSeconds = _rng.nextInt(241) - 120; // ±2 min jitter
    return Duration(seconds: totalSeconds + jitterSeconds);
  }

  int _countGrades(String html) {
    if (html.isEmpty) return 0;
    return _university == 'SU' ? _countSuGrades(html) : _countTuGrades(html);
  }

  /// TU — counts occurrences of "оценк[аи]" in the HTML.
  int _countTuGrades(String html) {
    final pattern = RegExp(r'oценк[аи]', caseSensitive: false);
    return pattern.allMatches(html).length;
  }

  /// SU — counts _lblMark spans that contain an actual numeric grade.
  /// Empty spans (subject not yet graded) are ignored.
  int _countSuGrades(String html) {
    final pattern = RegExp(
      r'_lblMark">(\d[\d.]*)<\/span>',
      caseSensitive: false,
    );
    return pattern.allMatches(html).length;
  }
}