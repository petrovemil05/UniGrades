import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unigrades/viewmodels/grade_monitor_viewmodel.dart';

class GradeActions extends StatelessWidget {
  const GradeActions({super.key});

  Color _dotColor(String status) {
    switch (status) {
      case GradeMonitorViewModel.statusTracking:
        return Colors.green;
      case GradeMonitorViewModel.statusChecking:
        return Colors.yellow;
      case GradeMonitorViewModel.statusError:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GradeMonitorViewModel>(
      builder: (context, vm, child) {
        final color = _dotColor(vm.status);
        final pulsing = vm.status != GradeMonitorViewModel.statusOff;

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              if (vm.isMonitoring) {
                await vm.toggle();
                return;
              }
              final result = await showDialog<String>(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Text('Следене на оценки'),
                  content: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium,
                      children: [
                        const TextSpan(
                          text: 'Избери какви известия да получаваш.\n\n',
                        ),
                        const TextSpan(
                          text: '• Всички известия',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const TextSpan(text: ' — статус + нови оценки\n'),
                        const TextSpan(
                          text: '• Само нови оценки',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const TextSpan(text: ' — известие само при нова оценка\n\n'),
                        const TextSpan(text: 'Точките около бутона показват състоянието:\n'),
                        const TextSpan(
                          text: '• Зелено — следи\n',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(
                          text: '• Жълто — проверява\n',
                          style: TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(
                          text: '• Червено — грешка\n',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(
                          text: '• Сиво — изключено\n\n',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(
                          text: 'Проверките се пускат от сървъра, който събужда телефона само когато е време за проверка.',
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'cancel'),
                      child: const Text('Отказ'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, 'new_grade_only'),
                      child: const Text('Само нови оценки'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, 'all_notifications'),
                      child: const Text('Всички известия'),
                    ),
                  ],
                ),
              );
              if (result == null || result == 'cancel') return;
              await vm.toggle(notificationMode: result);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PulsingDot(color: color, pulsing: pulsing),
                const SizedBox(width: 8),
                Text(vm.toggleLabel),
                const SizedBox(width: 8),
                _PulsingDot(color: color, pulsing: pulsing),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  final bool pulsing;

  const _PulsingDot({required this.color, required this.pulsing});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void didUpdateWidget(covariant _PulsingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulsing && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.pulsing && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final scale = widget.pulsing ? 0.86 + (_controller.value * 0.28) : 1.0;
        final opacity = widget.pulsing ? 0.45 + (_controller.value * 0.55) : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(opacity),
              shape: BoxShape.circle,
              boxShadow: widget.pulsing
                  ? [
                BoxShadow(
                  color: widget.color.withOpacity(0.35 * opacity),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
                  : const [],
            ),
          ),
        );
      },
    );
  }
}