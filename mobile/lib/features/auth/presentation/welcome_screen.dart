import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/firebase/providers.dart';

/// M01 · FR-AUTH-001. Google/Firebase owns credential entry and persistence.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.data_usage, size: 64),
                  const SizedBox(height: 24),
                  Text('μToken',
                      style: Theme.of(context).textTheme.displaySmall,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  const Text('Hiểu cách bạn sử dụng AI',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  const Text(
                      'Theo dõi token, chi phí và hiệu suất từ máy tính trên điện thoại của bạn.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  if (auth.message != null) ...[
                    Semantics(
                        liveRegion: true,
                        child: Text(auth.message!,
                            key: const Key('auth-message'),
                            textAlign: TextAlign.center)),
                    const SizedBox(height: 20),
                  ],
                  FilledButton.icon(
                    key: const Key('google-sign-in'),
                    onPressed: auth.busy
                        ? null
                        : ref.read(authControllerProvider.notifier).signIn,
                    icon: auth.busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.login),
                    label: Text(
                        auth.busy ? 'Đang đăng nhập…' : 'Continue with Google'),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                      'Dùng cùng tài khoản Google trên điện thoại và desktop. Nội dung hội thoại và mã nguồn luôn ở trên máy tính.',
                      textAlign: TextAlign.center),
                ])),
      ))),
    );
  }
}
