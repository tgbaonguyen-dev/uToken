import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/router.dart';
import 'core/widgets/ui_preview_scope.dart';
import 'features/auth/data/firebase_mobile_auth.dart';
import 'features/auth/domain/mobile_auth.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: UTokenApp()));
}

class UTokenApp extends StatefulWidget {
  const UTokenApp({super.key});
  @override
  State<UTokenApp> createState() => _UTokenAppState();
}

class _UTokenAppState extends State<UTokenApp> {
  MobileAuthController? _auth;
  GoRouter? _router;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _failed = false);
    try {
      // Android options come from google-services.json generated resources.
      await Firebase.initializeApp();
      if (!mounted) return;
      final auth = MobileAuthController(FirebaseMobileAuth());
      setState(() {
        _auth = auth;
        _router = createAppRouter(auth: auth);
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _router?.dispose();
    _auth?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
        fontFamily: 'BeVietnamPro',
        brightness: Brightness.dark,
        useMaterial3: true);
    if (_router == null) {
      return MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          home: Scaffold(
              body: SafeArea(
                  child: Center(
                      child: _failed
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                        'Firebase could not start. Check the Android Firebase configuration.'),
                                    const SizedBox(height: 16),
                                    FilledButton(
                                        onPressed: _initialize,
                                        child: const Text('Retry')),
                                  ]))
                          : const CircularProgressIndicator(
                              semanticsLabel: 'Starting Firebase')))));
    }
    return MobileAuthScope(
        controller: _auth!,
        child: UiPreviewScope(
          enabled: false,
          child: MaterialApp.router(
              title: '\u03bcToken',
              debugShowCheckedModeBanner: false,
              theme: theme,
              builder: (context, child) =>
                  MobileAuthScope.maybeOf(context)?.demoMode == true
                      ? Banner(
                          message: 'DEMO',
                          location: BannerLocation.topEnd,
                          child: child!)
                      : child!,
              routerConfig: _router),
        ));
  }
}
