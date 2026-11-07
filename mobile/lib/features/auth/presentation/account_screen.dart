import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/firebase/providers.dart';

/// M13 · FR-AUTH-001.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const Icon(Icons.account_circle_outlined, size: 72),
        const SizedBox(height: 16),
        Text(auth.user?.displayName ?? 'Google Account',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        if (auth.user?.email != null)
          Text(auth.user!.email!, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        if (auth.message != null)
          Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(auth.message!)),
        OutlinedButton.icon(
          key: const Key('sign-out'),
          onPressed: auth.busy
              ? null
              : ref.read(authControllerProvider.notifier).signOut,
          icon: const Icon(Icons.logout),
          label: Text(auth.busy ? 'Đang đăng xuất…' : 'Đăng xuất'),
        ),
      ]),
    );
  }
}
