import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ui/main_page.dart';
import 'viewmodels/grade_monitor_viewmodel.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize notifications first (creates channels)
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint("Failed to init NotificationService: $e");
  }

  // 2. Initialize background service configuration
  try {
    await BackgroundService.initialize();
  } catch (e) {
    debugPrint("Failed to init BackgroundService: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GradeMonitorViewModel()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'e-student',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MainPage(),
    );
  }
}
