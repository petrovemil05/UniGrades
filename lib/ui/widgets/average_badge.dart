import 'package:flutter/material.dart';
import 'package:e_student/models/average_result.dart';

class AverageBadge extends StatelessWidget {
  final AverageResult averageResult;

  const AverageBadge({super.key, required this.averageResult});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF2ECC71), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.analytics, color: Color(0xFF2ECC71)),
              const SizedBox(width: 10),
              Text(
                'Среден успех: ${averageResult.average.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            averageResult.semesterLabels.join(' и '),
            textAlign: TextAlign.center,
            style:  TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontStyle: FontStyle.italic
            ),
          ),
        ],
      ),
    );
  }
}