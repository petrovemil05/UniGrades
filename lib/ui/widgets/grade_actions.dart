import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:e_student/viewmodels/grade_monitor_viewmodel.dart';

class GradeActions extends StatelessWidget {
  const GradeActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GradeMonitorViewModel>(
      builder: (context, vm, child) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              if (vm.isMonitoring) { await vm.toggle(); return; }
              final result = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Следене на оценки'),
                  content: const Text(
                    'Следенето на оценки работи във фонов режим и проверява '
                        'за нови оценки периодично.\n\n'
                        'Това може да увеличи използването на батерията и не гарантира '
                        'абсолютно точни времена на проверка, тъй като Android може '
                        'да ограничава фоновите процеси.\n\n'
                        'Желаете ли да продължите?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отказ'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Продължи'),
                    ),
                  ],
                ),
              );
              if (result == true) await vm.toggle();
            },
            child: Text(vm.toggleLabel),
          ),
        );
      },
    );
  }
}