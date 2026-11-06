import 'package:flutter/material.dart';

import 'app/router.dart';

/// Entry point for reviewing 20 Figma UI frames without Firebase credentials.
/// Run: flutter run -t lib/main_ui_preview.dart
void main() => runApp(const UTokenUiPreview());

class UTokenUiPreview extends StatelessWidget {
  const UTokenUiPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'μToken UI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'BeVietnamPro',
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        fontFamily: 'BeVietnamPro',
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
