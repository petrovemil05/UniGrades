import 'package:html_unescape/html_unescape.dart';
import '../models/grade_item.dart';
import '../models/average_result.dart';

class TuGradesParser {
  final unescape = HtmlUnescape();

  String _colorForGrade(String gradeText) {
    if (gradeText.contains("Няма оценка")) return "Blue";
    if (gradeText.contains("Зачита се") || gradeText.contains("(6)")) return "Green";
    if (gradeText.contains("(5)")) return "Cyan";
    if (gradeText.contains("(4)")) return "Yellow";
    if (gradeText.contains("(3)")) return "Orange";
    if (gradeText.contains("(2)")) return "Red";
    return "White";
  }

  /// Extracts just the human name + numeric grade, e.g. "Добър (4)".
  /// Strips the trailing type tag like "(редовна)", "(поправителна)", etc.
  String _extractLabel(String entry) {
    // entry looks like: "Добър (4) (редовна), по протокол …"
    // We want everything up to and including the numeric "(N)" part.
    final match = RegExp(r'^(.+?\(\d\))').firstMatch(entry);
    return match != null ? match.group(1)!.trim() : entry.trim();
  }

  GradeItem _buildGradeItem(String subject, String block) {
    final headerMatch = RegExp(
      r'oценк[аи]:<br>\s*',
      caseSensitive: false,
    ).firstMatch(block);

    if (headerMatch == null) {
      return GradeItem(subject: subject, grade: "Няма оценка", color: "Blue");
    }

    final afterHeader = block.substring(headerMatch.end);
    final closingItalic = afterHeader.indexOf('</i>');
    final gradeSection = closingItalic != -1
        ? afterHeader.substring(0, closingItalic)
        : afterHeader;

    // Capture each entry: "Name (N) (тип)" — everything before ", по протокол"
    final entries = RegExp(r'([^\n<]+?\(\d\)\s*\([^)]+\))', caseSensitive: false)
        .allMatches(gradeSection)
        .map((m) => unescape.convert(m.group(1)!).trim())
    // Strip any leftover HTML tag remnants (e.g. a stray "br>" or ">"
    // left over from a "<br>" separator that got split mid-tag).
        .map((s) => s.replaceFirst(RegExp(r'^(?:[a-zA-Z]*>)+\s*'), ''))
        .toList();

    if (entries.isEmpty) {
      return GradeItem(subject: subject, grade: "Няма оценка", color: "Blue");
    }

    final lastEntry = entries.last;
    final isPoravka = lastEntry.contains("поправителна") ||
        lastEntry.contains("ликвидационна");

    final label = _extractLabel(lastEntry);
    final displayGrade = isPoravka ? "$label (П)" : label;

    return GradeItem(
      subject: subject,
      grade: displayGrade,
      color: _colorForGrade(lastEntry),
    );
  }

  List<GradeItem> parse(String html) {
    List<GradeItem> grades = [];

    final pattern = RegExp(
      r'<td colspan=4><center><b>(?<semester>[^<]+)</b>|<span[^>]*><b>(?<subject>[^<]+)</b>',
      caseSensitive: false,
      multiLine: true,
    );

    final matches = pattern.allMatches(html).toList();

    for (int i = 0; i < matches.length; i++) {
      final m = matches[i];
      final String? semesterGroup = m.namedGroup('semester');
      final String? subjectGroup = m.namedGroup('subject');

      if (semesterGroup != null && semesterGroup.isNotEmpty) {
        grades.add(GradeItem(
          grade: "== ${semesterGroup.trim()} ==",
          subject: "",
          color: "White",
        ));
        continue;
      }

      if (subjectGroup != null) {
        final subject = unescape.convert(subjectGroup).trim();
        final int blockEnd =
        (i + 1 < matches.length) ? matches[i + 1].start : html.length;
        final String block = html.substring(m.start, blockEnd);
        grades.add(_buildGradeItem(subject, block));
      }
    }

    // Reverse semester groups so latest appears first
    List<List<GradeItem>> groups = [];
    List<GradeItem>? currentGroup;

    for (var item in grades) {
      if (item.isSemester) {
        currentGroup = [item];
        groups.add(currentGroup);
      } else {
        currentGroup?.add(item);
      }
    }

    List<GradeItem> finalList = [];
    for (var g in groups.reversed) {
      finalList.addAll(g);
    }

    return finalList;
  }

  AverageResult? calculateAverage(List<GradeItem> allGrades) {
    List<Map<String, dynamic>> semesters = [];
    List<GradeItem>? currentSemesterGrades;
    String currentSemesterLabel = "";

    for (var item in allGrades) {
      if (item.isSemester) {
        currentSemesterGrades = [];
        currentSemesterLabel = item.grade.replaceAll("==", "").trim();
        semesters.add({
          'label': currentSemesterLabel,
          'grades': currentSemesterGrades,
        });
      } else {
        currentSemesterGrades?.add(item);
      }
    }

    final gradeValuePattern = RegExp(r'\((\d)\)');
    List<Map<String, dynamic>> validSemesters = [];

    for (var sem in semesters) {
      List<double> numericGrades = [];
      List<GradeItem> items = sem['grades'] as List<GradeItem>;

      for (var item in items) {
        if (item.grade.contains("Няма оценка") ||
            item.grade.contains("Зачита се")) {
          continue;
        }

        // grade is now like "Добър (4)" or "Добър (4) (П)"
        // gradeValuePattern picks up the first (N) which is always the numeric grade
        final match = gradeValuePattern.firstMatch(item.grade);
        if (match != null) {
          final val = double.parse(match.group(1)!);
          if (val >= 2) numericGrades.add(val);
          // (2) grades — whether редовна or failed поправка — are excluded
        }
      }

      if (numericGrades.isNotEmpty) {
        validSemesters.add({
          'label': sem['label'],
          'numericGrades': numericGrades,
        });
      }
    }

    if (validSemesters.isEmpty) return null;

    List<double> gradesToAverage = [];
    List<String> labelsUsed = [];
    int semestersCounted = 0;

    for (var sem in validSemesters) {
      gradesToAverage.addAll(sem['numericGrades'] as List<double>);
      labelsUsed.add(sem['label'] as String);
      semestersCounted++;
      if (semestersCounted == 2) break;
    }

    if (gradesToAverage.isEmpty) return null;

    final sum = gradesToAverage.reduce((a, b) => a + b);
    return AverageResult(
      average: sum / gradesToAverage.length,
      semesterLabels: labelsUsed,
    );
  }
}