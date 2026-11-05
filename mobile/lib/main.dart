import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android đọc cấu hình từ android/app/google-services.json (không commit).
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: UTokenApp()));
}

class UTokenApp extends StatelessWidget {
  const UTokenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'μToken',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF2A55C9), useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF2A55C9),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
    );
  }
}
