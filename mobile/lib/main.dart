import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'core/firebase/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android đọc cấu hình từ android/app/google-services.json (không commit).
  try {
    await Firebase.initializeApp();
    runApp(const ProviderScope(child: UTokenApp()));
  } catch (_) {
    runApp(const MaterialApp(
        home: Scaffold(
            body: Center(
                child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
            'Không khởi tạo được dịch vụ đăng nhập. Vui lòng kiểm tra kết nối hoặc cấu hình ứng dụng.'),
        SizedBox(height: 16),
        FilledButton(onPressed: main, child: Text('Thử lại')),
      ]),
    )))));
  }
}

class UTokenApp extends ConsumerStatefulWidget {
  const UTokenApp({super.key});
  @override
  ConsumerState<UTokenApp> createState() => _UTokenAppState();
}

class _UTokenAppState extends ConsumerState<UTokenApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(authControllerProvider.notifier).validateSession();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'μToken',
      theme: ThemeData(
          colorSchemeSeed: const Color(0xFF2A55C9), useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF2A55C9),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
