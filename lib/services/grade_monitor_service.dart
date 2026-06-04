import 'dart:async';
import 'package:intl/intl.dart';
import 'tu_api_service.dart';
import 'notification_service.dart';

class GradeMonitorService {
  int _lastGradeCount = -1;
  final String fnum;
  final String egn;
  final TuApiService _api = TuApiService();

  static const int persistentNotifId = 1001;
  static const int gradeAlertNotifId = 1002;

  GradeMonitorService({required this.fnum, required this.egn});

  Future<void> checkOnce() async {
    try {
      await _checkGrades();
    } catch (e) {
      NotificationService.showAlert(gradeAlertNotifId, "Грешка при проверка", e.toString());
    }
  }

  Future<void> _checkGrades() async {
    try {
      String time = DateFormat('HH:mm:ss').format(DateTime.now());
      NotificationService.showPersistent(persistentNotifId, "⏳ Проверявам…", time);

      String html = await _api.getHtmlAsync(fnum, egn);
      int currentCount = _countOtsenka(html);

      if (_lastGradeCount == -1) {
        _lastGradeCount = currentCount;
        NotificationService.showPersistent(
          persistentNotifId,
          "✅ Активно следене",
          "Първа проверка: $time | Оценки: $currentCount",
        );
      } else if (currentCount > _lastGradeCount) {
        int newGrades = currentCount - _lastGradeCount;
        int previousCount = _lastGradeCount;
        _lastGradeCount = currentCount;
        
        String alertBody = newGrades == 1
            ? "Получихте нова оценка в e-university!"
            : "Получихте $newGrades нови оценки в e-university!";
            
        NotificationService.showAlert(gradeAlertNotifId, "🎓 Нова оценка!", alertBody);
        NotificationService.showPersistent(
          persistentNotifId,
          "🎓 Нова оценка засечена!",
          "$time | Беше: $previousCount → Сега: $currentCount",
        );
      } else {
        _lastGradeCount = currentCount;
        Duration next = timeUntilNextHalfHour();
        String nextTime = DateFormat('HH:mm').format(DateTime.now().add(next));
        
        NotificationService.showPersistent(
          persistentNotifId,
          "✅ Няма промяна",
          "Проверено: $time | Оценки: $currentCount | Следваща: $nextTime",
        );
      }
    } catch (e) {
      String time = DateFormat('HH:mm:ss').format(DateTime.now());
      NotificationService.showPersistent(
        persistentNotifId,
        "❌ Грешка при проверка",
        "$time | $e",
      );
      NotificationService.showAlert(gradeAlertNotifId, "Грешка при проверка", e.toString());
    }
  }

  Duration timeUntilNextHalfHour() {
    DateTime now = DateTime.now();
    int nextMinute = now.minute < 30 ? 30 : 60;
    DateTime next = DateTime(now.year, now.month, now.day, now.hour, 0)
        .add(Duration(minutes: nextMinute));
    if (next.isBefore(now) || next.isAtSameMomentAs(now)) {
      next = next.add(const Duration(hours: 1));
    }
    return next.difference(now);
  }

  int _countOtsenka(String html) {
    if (html.isEmpty) return 0;
    // The user said "it needs only one o".
    final pattern = RegExp(r'oценк[аи]', caseSensitive: false);
    return pattern.allMatches(html).length;
  }
}
