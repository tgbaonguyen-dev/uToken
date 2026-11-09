import 'package:flutter/material.dart';
import '../../../core/data/usage_repository.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen(
      {super.key, required this.uid, required this.repository});
  final String uid;
  final UsageRepository repository;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: StreamBuilder(
          stream: repository.watchEfficiency(uid: uid),
          builder: (context, s) {
            if (s.hasError) {
              return Center(child: Text('Không thể đọc dữ liệu: ${s.error}'));
            }
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final d = s.data;
            if (d == null) return const Center(child: Text('Không có dữ liệu'));
            return ListView(padding: const EdgeInsets.all(16), children: [
              const Text('Process metrics'),
              ...d.processMetrics.map((m) => ListTile(
                  title: Text(m.metric),
                  subtitle: Text(m.provider ?? 'Tổng'),
                  trailing: Text(m.label)))
            ]);
          }));
}
