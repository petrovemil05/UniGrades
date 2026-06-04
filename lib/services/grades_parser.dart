import 'package:html_unescape/html_unescape.dart';
import '../models/grade_item.dart';

class AverageResult {
  final double average;
  final List<String> semesterLabels;

  AverageResult({required this.average, required this.semesterLabels});
}

class GradesParser {
  final unescape = HtmlUnescape();

  List<GradeItem> parse(String html) {
    List<GradeItem> grades = [];

    final pattern = RegExp(
      r'<td colspan=4><center><b>(?<semester>[^<]+)</b>|<span[^>]*><b>(?<subject>[^<]+)</b>',
      caseSensitive: false,
      multiLine: true,
    );

    final matches = pattern.allMatches(html);

    for (var m in matches) {
      String? semesterGroup = m.namedGroup('semester');
      String? subjectGroup = m.namedGroup('subject');

      // SEMESTER
      if (semesterGroup != null && semesterGroup.isNotEmpty) {
        grades.add(GradeItem(
          grade: "== ${semesterGroup.trim()} ==",
          subject: "",
          color: "White",
        ));
        continue;
      }

      // SUBJECT
      if (subjectGroup != null) {
        String subject = unescape.convert(subjectGroup).trim();

        int start = m.start;
        String remainingHtml = html.substring(m.end);

        final nextMatch = RegExp(
          r'<span[^>]*><b>|<td colspan=4><center><b>',
          caseSensitive: false,
        ).firstMatch(remainingHtml);

        int end = nextMatch != null ? m.end + nextMatch.start : html.length;

        String block = html.substring(start, end);

        final gradeMatch = RegExp(
          r'oценк[аи]:<br>\s*([^<]+?\(\d\))',
          caseSensitive: false,
        ).firstMatch(block);

        String grade = gradeMatch != null
            ? unescape.convert(gradeMatch.group(1)!).trim()
            : "Няма оценка";

        // COLOR RULES
        String color = "White";
        if (grade.contains("Няма оценка")) {
          color = "Blue";
        } else if (grade.contains("Зачита се") || grade.contains("(6)")) {
          color = "Green";
        } else if (grade.contains("(5)")) {
          color = "Cyan";
        } else if (grade.contains("(4)")) {
          color = "Yellow";
        } else if (grade.contains("(3)")) {
          color = "Orange";
        } else if (grade.contains("(2)")) {
          color = "Red";
        }

        grades.add(GradeItem(
          subject: subject,
          grade: grade,
          color: color,
        ));
      }
    }

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

    var reversedGroups = groups.reversed.toList();
    List<GradeItem> finalList = [];
    for (var g in reversedGroups) {
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

    List<Map<String, dynamic>> validSemesters = [];
    final gradeValuePattern = RegExp(r'\((\d)\)');

    for (var sem in semesters) {
      List<double> numericGrades = [];
      List<GradeItem> items = sem['grades'];
      for (var item in items) {
        if (item.grade.contains("Няма оценка") || item.grade.contains("Зачита се")) {
          continue;
        }
        
        var match = gradeValuePattern.firstMatch(item.grade);
        if (match != null) {
          double val = double.parse(match.group(1)!);
          if (val > 1) { 
            numericGrades.add(val);
          }
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

    double sum = gradesToAverage.reduce((a, b) => a + b);
    return AverageResult(
      average: sum / gradesToAverage.length,
      semesterLabels: labelsUsed,
    );
  }
}
