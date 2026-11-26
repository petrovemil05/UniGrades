import 'package:shared_preferences/shared_preferences.dart';
import '../models/grade_item.dart';
import 'web_notification_factory/web_notification_factory.dart';

class WebGradeChangeDetector {
  static const String _storedGradesKey = 'web_last_grades';

  static Future<void> checkForNewGrades(List<GradeItem> grades) async {
    final prefs = await SharedPreferences.getInstance();

    final currentGrades = grades
        .where((grade) => !grade.isSemester)
        .map((grade) => '${grade.subject}|${grade.grade}')
        .toList()
      ..sort();

    final current = currentGrades.join('\n');
    final previous = prefs.getString(_storedGradesKey) ?? '';

    if (previous.isEmpty) {
      await prefs.setString(_storedGradesKey, current);
      return;
    }

    if (current == previous) {
      return;
    }

    final previousSet = previous.split('\n').toSet();
    final newGrades = currentGrades
        .where((grade) => !previousSet.contains(grade))
        .toList();

    await prefs.setString(_storedGradesKey, current);

    if (newGrades.isNotEmpty) {
      final subjectCount = newGrades.length;

      await showWebNotification(
        'Нова оценка в UniGrades',
        'Открити са $subjectCount нови промени в оценките.',
      );
    }
  }
}