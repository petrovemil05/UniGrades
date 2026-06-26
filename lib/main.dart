import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ui/main_page.dart';
import 'ui/university_picker_page.dart';
import 'viewmodels/grade_monitor_viewmodel.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try { await NotificationService.init(); }
  catch (e) { debugPrint('Failed to init NotificationService: $e'); }

  try { await BackgroundService.initialize(); }
  catch (e) { debugPrint('Failed to init BackgroundService: $e'); }

  // Determine start page before runApp so there's no flash
  final prefs      = await SharedPreferences.getInstance();
  final university = prefs.getString(UniversityPickerPage.prefKey) ?? '';
  final Widget home = university.isEmpty
      ? const UniversityPickerPage()
      : const MainPage();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GradeMonitorViewModel()),
      ],
      child: MyApp(home: home),
    ),
  );
}

class MyApp extends StatelessWidget {
  final Widget home;
  const MyApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniGrades',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: home,
    );
  }
}