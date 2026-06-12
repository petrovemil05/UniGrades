import 'dart:async';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tu_api_service.dart';
import 'notification_service.dart';

class GradeMonitorService {
  final String fnum;
  final String egn;
  final TuApiService _api = TuApiService();
  final _rng = Random();

  // Callback to update status without relying on NotificationService
  final Function(String title, String body)? onStatusUpdate;

  static const int persistentNotifId = 1001;
  static const int gradeAlertNotifId = 1002;
  static const String _prefLastCountKey = "last_grade_count";

  GradeMonitorService({
    required this.fnum,
    required this.egn,
    this.onStatusUpdate,
  });

  Future<void> checkOnce() async {
    try {
      await _checkGrades();
    } catch (e) {
      _updateStatus("❌ Грешка при проверка", e.toString());
      try {
        NotificationService.showAlert(gradeAlertNotifId, "Грешка при проверка", e.toString());
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
    try {
      String time = DateFormat('HH:mm:ss').format(DateTime.now());
      _updateStatus("⏳ Проверявам…", time);

      final prefs = await SharedPreferences.getInstance();
      int lastGradeCount = prefs.getInt(_prefLastCountKey) ?? -1;

      String html = await _api.getHtmlAsync(fnum, egn);
      int currentCount = _countOtsenka(html);

      if (lastGradeCount == -1) {
        await prefs.setInt(_prefLastCountKey, currentCount);
        _updateStatus(
          "✅ Активно следене",
          "Първа проверка: $time | Оценки: $currentCount",
        );
      } else if (currentCount > lastGradeCount) {
        int newGrades = currentCount - lastGradeCount;
        int previousCount = lastGradeCount;
        await prefs.setInt(_prefLastCountKey, currentCount);

        String alertBody = newGrades == 1
            ? "Получихте нова оценка в e-university!"
            : "Получихте $newGrades нови оценки в e-university!";

        _updateStatus(
          "🎓 Нова оценка засечена!",
          "$time | Беше: $previousCount → Сега: $currentCount",
        );

        try {
          NotificationService.showAlert(gradeAlertNotifId, "🎓 Нова оценка!", alertBody);
        } catch (_) {}
      } else {
        await prefs.setInt(_prefLastCountKey, currentCount);
        Duration next = timeUntilNextHalfHour();
        String nextTime = DateFormat('HH:mm').format(DateTime.now().add(next));

        _updateStatus(
          "✅ Няма промяна",
          "Проверено: $time | Оценки: $currentCount | Следваща: $nextTime",
        );
      }
    } catch (e) {
      String time = DateFormat('HH:mm:ss').format(DateTime.now());
      _updateStatus("❌ Грешка при проверка", "$time | $e");
    }
  }

  /// Returns 30 minutes plus a random jitter of ±2 minutes (±120 seconds).
  /// Anchoring to wall-clock :00/:30 boundaries caused double-fires when a
  /// negative jitter fired early — the next call would immediately target the
  /// same boundary again. A fixed 30-minute base avoids that entirely.
  Duration timeUntilNextHalfHour() {
    const int baseSeconds = 30 * 60; // 1800
    final int jitterSeconds = _rng.nextInt(241) - 120; // −120..+120
    return Duration(seconds: baseSeconds + jitterSeconds);
  }

  int _countOtsenka(String html) {
    if (html.isEmpty) return 0;
    final pattern = RegExp(r'oценк[аи]', caseSensitive: false);
    return pattern.allMatches(html).length;
  }
}