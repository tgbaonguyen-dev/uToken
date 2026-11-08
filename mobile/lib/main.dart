import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'core/widgets/ui_preview_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Real app entry point: Firebase remains initialized here.
  // Use main_ui_preview.dart to review the layout without credentials.
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: UTokenApp()));
}

class UTokenApp extends StatelessWidget {
  const UTokenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return UiPreviewScope(
        enabled: false,
        child: MaterialApp.router(
          title: 'μToken',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: 'BeVietnamPro',
            brightness: Brightness.light,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            fontFamily: 'BeVietnamPro',
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          themeMode: ThemeMode.dark,
          routerConfig: appRouter,
        ));
  }
}
