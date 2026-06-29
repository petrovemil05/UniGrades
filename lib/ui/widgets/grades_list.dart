import 'package:flutter/material.dart';
import 'package:unigrades/models/grade_item.dart';

class GradesList extends StatefulWidget {
  final List<GradeItem> grades;

  const GradesList({super.key, required this.grades});

  @override
  State<GradesList> createState() => _GradesListState();
}

class _GradesListState extends State<GradesList> {
  late final Set<int> _expandedSemesters;

  @override
  void initState() {
    super.initState();
    _expandedSemesters = {
      for (int i = 0; i < widget.grades.length; i++)
        if (widget.grades[i].isSemester) i
    };
  }

  Color _getGradeColor(String colorName) {
    switch (colorName) {
      case 'Green':  return const Color(0xFF2ECC71);
      case 'Red':    return const Color(0xFFE74C3C);
      case 'Blue':   return const Color(0xFF3498DB);
      case 'Yellow': return const Color(0xFFF1C40F);
      case 'Cyan':   return const Color(0xFF1ABC9C);
      case 'Orange': return const Color(0xFFE67E22);
      default:       return Colors.white;
    }
  }

  int _ownerSemesterIndex(int gradeIndex) {
    for (int i = gradeIndex - 1; i >= 0; i--) {
      if (widget.grades[i].isSemester) return i;
    }
    return -1;
  }

  bool _isVisible(int index) {
    final item = widget.grades[index];
    if (item.isSemester) return true;
    final owner = _ownerSemesterIndex(index);
    if (owner == -1) return true;
    return _expandedSemesters.contains(owner);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.grades.length,
      itemBuilder: (context, index) {
        if (!_isVisible(index)) return const SizedBox.shrink();

        final item = widget.grades[index];

        // ── Semester header ───────────────────────────────────────────────
        if (item.isSemester) {
          final isExpanded = _expandedSemesters.contains(index);
          return Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 0),
            child: InkWell(
              borderRadius: isExpanded
                  ? const BorderRadius.vertical(top: Radius.circular(10))
                  : BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedSemesters.remove(index);
                  } else {
                    _expandedSemesters.add(index);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: isExpanded
                      ? const BorderRadius.vertical(top: Radius.circular(10))
                      : BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF444444)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.grade,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.0 : -0.25,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.expand_more, color: Colors.white70, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // ── Grade row ─────────────────────────────────────────────────────
        final owner       = _ownerSemesterIndex(index);
        final hasSemester = owner != -1;

        bool isLastVisible = true;
        for (int i = index + 1; i < widget.grades.length; i++) {
          if (widget.grades[i].isSemester) break;
          if (_isVisible(i)) { isLastVisible = false; break; }
        }

        final borderRadius = hasSemester
            ? BorderRadius.vertical(
          bottom: isLastVisible ? const Radius.circular(10) : Radius.zero,
        )
            : BorderRadius.circular(10);

        return Container(
          margin: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: borderRadius,
            border: Border(
              left:   const BorderSide(color: Color(0xFF444444)),
              right:  const BorderSide(color: Color(0xFF444444)),
              bottom: isLastVisible
                  ? const BorderSide(color: Color(0xFF444444))
                  : BorderSide.none,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.subject,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.grade,
                    style: TextStyle(
                      color: _getGradeColor(item.color),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}