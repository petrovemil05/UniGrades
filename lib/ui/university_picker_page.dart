import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_page.dart';
import 'app_intro_dialog.dart';

class UniversityPickerPage extends StatefulWidget {
  const UniversityPickerPage({super.key});

  static const String prefKey = 'university';

  @override
  State<UniversityPickerPage> createState() => _UniversityPickerPageState();
}

class _UniversityPickerPageState extends State<UniversityPickerPage> {
  static const String _prefDisclaimerKey = 'disclaimer_accepted';

  @override
  void initState() {
    super.initState();
    _showDisclaimerIfNeeded();
  }

  Future<void> _showDisclaimerIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool(_prefDisclaimerKey) ?? false;
    if (accepted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Text('⚠️', style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Неофициално приложение',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Това приложение е неофициален проект и не е свързано с '
                'Технически университет — София или Софийски университет.'


            'То използва публично достъпните данни от студентските системи '
                'единствено за удобство на студентите.'


            'Данните се съхраняват само на устройството ти '
                'и не се изпращат никъде, освен към сървъра на избрания университет.',
            style: TextStyle(
              color: Color(0xFFBBBBBB),
              fontSize: 14,
              height: 1.55,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                showDialog(
                  context: context,
                  builder: (_) => const AppIntroDialog(),
                );
              },
              child: const Text('Помощ'),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  await prefs.setBool(_prefDisclaimerKey, true);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text(
                  'Разбрах',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _pick(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(UniversityPickerPage.prefKey, value);
    if (mounted) {
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
        child: Stack(
          children: [
            Padding(
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
                    'Изборът се запазва и може да се промени чрез излизане от горен ляв ъгъл.',
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
                    onTap: () => _pick('TU'),
                  ),
                  const SizedBox(height: 16),
                  _UniButton(
                    label: 'Софийски университет',
                    subtitle: '\'Св. Климент Охридски\'',
                    color: const Color(0xFF2ECC71),
                    icon: Icons.account_balance,
                    onTap: () => _pick('SU'),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.help_outline, color: Colors.white),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const AppIntroDialog(),
                  );
                },
              ),
            ),
          ],
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
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
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, color: color, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}