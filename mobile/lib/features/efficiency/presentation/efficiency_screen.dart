import 'package:flutter/material.dart';
import '../../../core/data/usage_repository.dart';

class EfficiencyScreen extends StatelessWidget {
  const EfficiencyScreen(
      {super.key, required this.uid, required this.repository});
  final String uid;
  final UsageRepository repository;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Efficiency')),
      body: StreamBuilder(
          stream: repository.watchEfficiency(uid: uid),
          builder: (context, s) {
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final d = s.data;
            if (d == null) return const Center(child: Text('Không có dữ liệu'));
            return ListView(padding: const EdgeInsets.all(16), children: [
              const Text('Setups'),
              ...d.setups.map((x) => ListTile(
                  title: Text('${x.model} · ${x.taskGroup}'),
                  subtitle: Text(
                      '${x.provider} · SR ${x.sr == null ? '—' : '${(x.sr! * 100).toStringAsFixed(1)}%'}'),
                  trailing: Text(x.verdict == 'insufficient'
                      ? 'Chưa đủ dữ liệu · ${x.tasks}/20'
                      : x.verdict)))
            ]);
          }));
}
