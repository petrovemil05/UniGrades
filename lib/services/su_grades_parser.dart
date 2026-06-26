import 'package:html_unescape/html_unescape.dart';
import '../models/grade_item.dart';
import '../models/average_result.dart';

class SuGradesParser {
  final _unescape = HtmlUnescape();

  static final _re = RegExp(
    '(?:<span id="Report_Exams1_rptYears__ctl\\d+_lblYear">(?<year>[^<]+)</span>)'
        '|(?:<span id="Report_Exams1_rptYears__ctl\\d+_rptSessions__ctl\\d+_lblSessionName">(?<session>[^<]+)</span>)'
        '|(?:<td[^>]*style="padding-left: 10px;" width="40%">\\s*(?<subject>[^<]+?)\\s*</td>.*?_lblTaken">(?<taken>да|не)</span>.*?_lblMark">(?<mark>[^<]*))</span>',
    dotAll: true,
  );

  String _decode(String s) => _unescape.convert(s).trim();

  String _color(bool taken, String mark) {
    if (!taken || mark.isEmpty) return 'Blue';
    final n = double.tryParse(mark);
    if (n == null) return 'White';
    if (n >= 6) return 'Green';
    if (n >= 5) return 'Cyan';
    if (n >= 4) return 'Yellow';
    if (n >= 3) return 'Orange';
    return 'Red';
  }

  String _gradeLabel(bool taken, String mark) {
    if (!taken || mark.isEmpty) return 'Няма оценка';
    final n = double.tryParse(mark);
    if (n == null) return mark;
    if (n >= 5.5) return 'Отличен (6)';
    if (n >= 4.5) return 'Много добър (5)';
    if (n >= 3.5) return 'Добър (4)';
    if (n >= 2.5) return 'Среден (3)';
    return 'Слаб (2)';
  }

  // ── Semester date logic ──────────────────────────────────────────────────

  int? _extractSecondYear(String label) {
    final match = RegExp(r'\d{4}/(\d{4})').firstMatch(label);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  DateTime? _sessionCutoff(String label) {
    final year2 = _extractSecondYear(label);
    if (year2 == null) return null;
    final lower = label.toLowerCase();
    if (lower.contains('януар')) return DateTime(year2, 1, 1);
    if (lower.contains('юн'))   return DateTime(year2, 6, 1);
    if (lower.contains('септ')) return DateTime(year2, 9, 1);
    return null;
  }

  bool _shouldInclude(GradeItem header, List<GradeItem> subjects) {
    final hasGrades = subjects.any((s) => !s.grade.contains('Няма оценка'));
    if (hasGrades) return true;
    final cutoff = _sessionCutoff(header.grade);
    if (cutoff == null) return false;
    return !DateTime.now().isBefore(cutoff);
  }

  // ── Public API ───────────────────────────────────────────────────────────

  List<GradeItem> parse(String html) {
    final rawList = <GradeItem>[];
    String? pendingYear;

    for (final m in _re.allMatches(html)) {
      final year    = m.namedGroup('year');
      final session = m.namedGroup('session');
      final subject = m.namedGroup('subject');

      if (year != null) { pendingYear = _decode(year); continue; }

      if (session != null) {
        final label = pendingYear != null
            ? '$pendingYear – ${_decode(session)}'
            : _decode(session);
        rawList.add(GradeItem(subject: '', grade: '== $label ==', color: 'White'));
        continue;
      }

      if (subject != null) {
        final taken = m.namedGroup('taken') == 'да';
        final mark  = m.namedGroup('mark')?.trim() ?? '';
        rawList.add(GradeItem(
          subject: _decode(subject),
          grade:   _gradeLabel(taken, mark),
          color:   _color(taken, mark),
        ));
      }
    }

    // Split into (header, subjects) groups
    final groups = <({GradeItem header, List<GradeItem> subjects})>[];
    List<GradeItem>? currentSubjects;
    for (final item in rawList) {
      if (item.isSemester) {
        currentSubjects = [];
        groups.add((header: item, subjects: currentSubjects));
      } else {
        currentSubjects?.add(item);
      }
    }

    // Reverse → latest first
    // Filter: keep if has grades OR today >= session cutoff date
    // NO hard cut — all passing semesters are shown
    final toShow = groups.reversed
        .where((g) => _shouldInclude(g.header, g.subjects))
        .toList();

    return [
      for (final g in toShow) ...[g.header, ...g.subjects],
    ];
  }

  AverageResult? calculateAverage(List<GradeItem> allGrades) {
    final List<Map<String, dynamic>> semesters = [];
    List<GradeItem>? currentSemesterGrades;
    String currentSemesterLabel = '';

    for (var item in allGrades) {
      if (item.isSemester) {
        currentSemesterGrades = [];
        currentSemesterLabel = item.grade.replaceAll('==', '').trim();
        semesters.add({'label': currentSemesterLabel, 'grades': currentSemesterGrades});
      } else {
        currentSemesterGrades?.add(item);
      }
    }

    final gradeValuePattern = RegExp(r'\((\d)\)');
    final List<Map<String, dynamic>> validSemesters = [];

    for (var sem in semesters) {
      final List<double> numericGrades = [];
      for (var item in sem['grades'] as List<GradeItem>) {
        if (item.grade.contains('Няма оценка') || item.grade.contains('Зачита се')) continue;
        final match = gradeValuePattern.firstMatch(item.grade);
        if (match != null) {
          final val = double.parse(match.group(1)!);
          if (val >= 3) numericGrades.add(val);
        }
      }
      if (numericGrades.isNotEmpty) {
        validSemesters.add({'label': sem['label'], 'numericGrades': numericGrades});
      }
    }

    if (validSemesters.isEmpty) return null;

    final List<double> gradesToAverage = [];
    final List<String> labelsUsed = [];
    int count = 0;
    for (var sem in validSemesters) {
      gradesToAverage.addAll(sem['numericGrades'] as List<double>);
      labelsUsed.add(sem['label'] as String);
      if (++count == 2) break;
    }

    if (gradesToAverage.isEmpty) return null;
    final sum = gradesToAverage.reduce((a, b) => a + b);
    return AverageResult(average: sum / gradesToAverage.length, semesterLabels: labelsUsed);
  }
}