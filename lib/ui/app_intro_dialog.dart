import 'package:flutter/material.dart';

class AppIntroDialog extends StatelessWidget {
  const AppIntroDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.86),
      fontSize: 14,
      height: 1.45,
    );

    Widget item(String title, String body, Color color) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.75), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(body, style: textStyle),
          ],
        ),
      );
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF121212),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Как се ползва UniGrades',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            item('1. Избери университет', 'Докосни ТУ-София или Софийски университет, за да запазиш избора си и да продължиш.', const Color(0xFF3498DB)),
            item('2. Въведи данните си', 'Попълни нужните данни за вход за избрания университет. Данните остават на устройството.', const Color(0xFF2ECC71)),
            item('3. Обновявай', 'Ползвай бутона за презареждане (горен десен ъгъл) или просто плъзни надолу, когато искаш да синхронизираш информацията ръчно.', const Color(0xFFF1C40F)),
            item('4. Сгъвай секциите', 'Отваряй и затваряй групите с оценки, за да виждаш само това, което ти трябва.', const Color(0xFFE67E22)),
            item('5. Следи оценките', 'Включи следенето, за да получаваш известия при нова оценка или само при нови оценки.', const Color(0xFFE74C3C)),
            item('6. Ъпдейтвай', 'Приложението автоматично получава обновления заедно със съобщение с новостите и опция за отлагане.', const Color(0xFF9B59B6)),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Разбрах',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
