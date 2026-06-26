import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_page.dart';

class UniversityPickerPage extends StatelessWidget {
  const UniversityPickerPage({super.key});

  static const String prefKey = 'university';

  Future<void> _pick(BuildContext context, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, value);
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.school, color: Colors.white, size: 72),
              const SizedBox(height: 32),
              const Text(
                'Избери университет',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Изборът се запазва и може да се промени от бутона „Изход".',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 48),
              _UniButton(
                label: 'ТУ — София',
                subtitle: 'Технически университет',
                color: const Color(0xFF3498DB),
                icon: Icons.engineering,
                onTap: () => _pick(context, 'TU'),
              ),
              const SizedBox(height: 16),
              _UniButton(
                label: 'СУ "Св Климент Охридски"',
                subtitle: 'Софийски университет',
                color: const Color(0xFF2ECC71),
                icon: Icons.account_balance,
                onTap: () => _pick(context, 'SU'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UniButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _UniButton({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color, width: 2),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios, color: color, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}