import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'services/fcm_service.dart';
import 'viewmodels/grade_monitor_viewmodel.dart';
import 'ui/main_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('FCM Token: $token');
      await FcmService.init();
    } catch (e) {
      debugPrint('Initialization error: $e');
    }
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => GradeMonitorViewModel(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniGrades',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const MainPage(),
    );
  }
}
