import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// M09 · FR-SETT-001
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: [
        ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: const Text('Account'),
            subtitle: const Text('Tài khoản Google và đăng xuất'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/account')),
      ]),
    );
  }
}
