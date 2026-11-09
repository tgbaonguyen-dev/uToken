import 'package:flutter/material.dart';
import '../../../core/data/usage_repository.dart';
import '../../../core/format/token_format.dart';
import '../../../core/models/daily_doc.dart';

class TokensScreen extends StatelessWidget {
  const TokensScreen({super.key, required this.uid, required this.repository});
  final String uid;
  final UsageRepository repository;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
        appBar: AppBar(title: const Text('Tokens')),
        body: StreamBuilder<List<DailyDoc>>(
            stream: repository.watchDaily(
                uid: uid,
                start: now.subtract(const Duration(days: 30)),
                end: now),
            builder: (context, s) {
              if (s.hasError) {
                return Center(child: Text('Không thể đọc dữ liệu: ${s.error}'));
              }
              if (!s.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = s.data!;
              final total = docs.fold<int>(0, (v, d) => v + d.totals.total);
              return ListView(padding: const EdgeInsets.all(16), children: [
                Text('30 ngày gần nhất',
                    style: Theme.of(context).textTheme.titleLarge),
                Card(
                    child: ListTile(
                        title: const Text('Tổng token'),
                        trailing:
                            Text(formatTokens(total, TokenFormat.compact)))),
                ...docs.map((d) => ListTile(
                    title: Text(d.date),
                    trailing: Text(
                        formatTokens(d.totals.total, TokenFormat.compact))))
              ]);
            }));
  }
}
