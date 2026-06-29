import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unigrades/viewmodels/grade_monitor_viewmodel.dart';

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
              if (vm.isMonitoring) {
                await vm.toggle();
                return;
              }
              final result = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Следене на оценки'),
                  content: const Text(
                    'Приложението ще получава известия при нова оценка '
                        'дори когато е затворено.\n\n'
                        'Проверките се извършват на сървър — '
                        'без влияние върху батерията на телефона.',
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