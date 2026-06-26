import 'package:flutter/material.dart';

class TimingSelector extends StatelessWidget {
  final int selectedMinutes;
  final ValueChanged<int> onChanged;

  const TimingSelector({
    super.key,
    required this.selectedMinutes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Проверка на',
          style: TextStyle(color: Colors.white70),
        ),
        DropdownButton<int>(
          value: selectedMinutes,
          dropdownColor: const Color(0xFF1E1E2E),
          style: const TextStyle(color: Colors.white),
          underline: const SizedBox(),
          items: const [
            DropdownMenuItem(value: 15, child: Text('15 минути')),
            DropdownMenuItem(value: 30, child: Text('30 минути')),
            DropdownMenuItem(value: 60, child: Text('1 час')),
            DropdownMenuItem(value: 120, child: Text('2 часа')),
            DropdownMenuItem(value: 240, child: Text('4 часа')),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ],
    );
  }
}