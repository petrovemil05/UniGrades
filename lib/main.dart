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
      await FcmService.init();
    } catch (e) {
      debugPrint('Initialization error: $e');
    }
  }

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyDDFjJ9QG8uikqozLwP7RzPg66g32rOsXo',
        authDomain: 'udes-54aad.firebaseapp.com',
        projectId: 'udes-54aad',
        storageBucket: 'udes-54aad.firebasestorage.app',
        messagingSenderId: '1047197774233',
        appId: '1:1047197774233:web:ce95558cb3615bfdb6a308',
      ),
    );
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
