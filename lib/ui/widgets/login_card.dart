import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../university_picker_page.dart';

class LoginCard extends StatelessWidget {
  final TextEditingController user1Controller;
  final TextEditingController user2Controller;
  final String field1Hint;
  final String field2Hint;
  final bool field2Obscure;
  final TextInputType fieldKeyboardType;
  final VoidCallback onLoginClicked;

  const LoginCard({
    super.key,
    required this.user1Controller,
    required this.user2Controller,
    required this.field1Hint,
    required this.field2Hint,
    required this.field2Obscure,
    required this.fieldKeyboardType,
    required this.onLoginClicked,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Вход',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: user1Controller,
              decoration: InputDecoration(
                hintText: field1Hint,
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.transparent,
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: fieldKeyboardType,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: user2Controller,
              decoration: InputDecoration(
                hintText: field2Hint,
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.transparent,
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: fieldKeyboardType,
              obscureText: field2Obscure,
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onLoginClicked,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Вход', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove(UniversityPickerPage.prefKey);
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const UniversityPickerPage()),
                    );
                  }
                },
                icon: const Icon(Icons.arrow_back, size: 16, color: Colors.grey),
                label: const Text(
                  'Промени университет',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}