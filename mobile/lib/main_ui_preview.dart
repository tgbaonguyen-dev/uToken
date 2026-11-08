import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'core/widgets/ui_preview_scope.dart';

/// Entry point for reviewing 24 Figma UI frames without Firebase credentials.
/// Run: flutter run -t lib/main_ui_preview.dart
void main() => runApp(const ProviderScope(child: UTokenUiPreview()));

class UTokenUiPreview extends StatelessWidget {
  const UTokenUiPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return UiPreviewScope(
        enabled: true,
        child: MaterialApp.router(
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
          themeMode: ThemeMode.dark,
          routerConfig: appRouter,
        ));
  }
}
