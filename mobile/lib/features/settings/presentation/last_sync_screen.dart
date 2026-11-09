import 'package:flutter/material.dart';

import '../../../core/data/usage_repository.dart';
import '../../../core/widgets/real_screen_scaffold.dart';

/// M10 desktop synchronization status.
class LastSyncScreen extends StatelessWidget {
  const LastSyncScreen(
      {super.key, required this.uid, required this.repository});
  final String uid;
  final UsageRepository repository;

  @override
  Widget build(BuildContext context) => RealScreenScaffold(
        title: 'Desktop connection',
        selectedIndex: 3,
        body: StreamBuilder<DateTime?>(
          stream: repository.watchLastSync(uid: uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final value = snapshot.data;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Desktop sync'),
                      const SizedBox(height: 8),
                      Text(value == null ? '—' : 'Đồng bộ ${_relative(value)}'),
                      const SizedBox(height: 8),
                      const Text(
                        'Đăng nhập cùng tài khoản Google trên ứng dụng máy tính để kết nối.',
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

  String _relative(DateTime value) {
    final minutes = DateTime.now().difference(value).inMinutes;
    if (minutes < 1) return 'vừa xong';
    if (minutes < 60) return '$minutes phút trước';
    final hours = minutes ~/ 60;
    if (hours < 24) return '$hours giờ trước';
    return '${hours ~/ 24} ngày trước';
  }
}
