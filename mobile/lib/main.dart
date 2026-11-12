import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/router.dart';
import 'core/ui/ut_kit.dart' show UtColors, UtText;
import 'core/widgets/ui_preview_scope.dart';
import 'core/data/cached_usage_repository.dart';
import 'core/data/local_prefs.dart';
import 'core/data/usage_repository.dart';
import 'core/firebase/crash_reporter.dart';
import 'features/ai_review/phone_judge.dart';
import 'features/auth/data/firebase_mobile_auth.dart';
import 'features/auth/domain/mobile_auth.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the status and navigation bars (Android 15 forces this
  // anyway) with light icons on the dark UI.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  ));
  LocalPrefs.instance = LocalPrefs(const SecurePrefsStore())..load();
  PhoneJudge.instance = PhoneJudge(const SecurePrefsStore())..load();
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
      await CrashReporter.install();
      if (!mounted) return;
      final auth = MobileAuthController(FirebaseMobileAuth());
      setState(() {
        _auth = auth;
        _router = createAppRouter(
          auth: auth,
          // One shared, replaying listener per document: tab switches and
          // back navigation show data instantly.
          usage: CachedUsageRepository(FirestoreUsageRepository(
            firestore: FirebaseFirestore.instance,
          )),
        );
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
        useMaterial3: true,
        scaffoldBackgroundColor: UtColors.background,
        colorScheme: const ColorScheme.dark(
          surface: UtColors.card,
          primary: UtColors.text,
          onPrimary: UtColors.primaryButtonText,
          secondary: UtColors.orange,
          error: Color(0xFFE0525B),
          outline: UtColors.cardBorder,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: UtColors.card,
          titleTextStyle: UtText.title,
          contentTextStyle: UtText.body.copyWith(fontSize: 14, height: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: UtColors.cardBorder)),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: UtColors.card, showDragHandle: true),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: UtColors.chip,
          contentTextStyle: const TextStyle(
              fontFamily: 'BeVietnamPro', fontSize: 13, color: UtColors.text),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: UtColors.cardBorder)),
        ),
        // Android-sized tap targets (48dp) everywhere.
        materialTapTargetSize: MaterialTapTargetSize.padded,
        // Detail screens slide in from the right with swipe-back, the same
        // on every platform; tabs use their own cross-fade (see router).
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        }),
        splashFactory: InkRipple.splashFactory);
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
