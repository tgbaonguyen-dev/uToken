import 'package:flutter/material.dart';
import '../../../core/data/usage_repository.dart';
import '../../../core/models/usage_docs.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen(
      {super.key, required this.uid, required this.repository});
  final String uid;
  final UsageRepository repository;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: StreamBuilder<InsightsDoc?>(
          stream: repository.watchInsights(uid: uid),
          builder: (context, s) {
            if (s.hasError) {
              return Center(child: Text('Không thể đọc dữ liệu: ${s.error}'));
            }
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final d = s.data;
            if (d == null) {
              return const Center(
                  child: Text(
                      'Chưa có đánh giá AI. Mở uToken trên máy tính và bấm Sync.'));
            }
            final provider = switch (d.provider) {
              'google' => 'Gemini',
              'anthropic' => 'Claude',
              'openai' => 'OpenAI',
              _ => 'không rõ'
            };
            return ListView(padding: const EdgeInsets.all(16), children: [
              Text('${d.grade ?? '—'} · ${d.score ?? '—'}',
                  style: Theme.of(context).textTheme.headlineMedium),
              Text(d.headline),
              Text('Đánh giá bởi $provider · ${d.model ?? 'model không rõ'}'),
              Text('Tạo lúc ${d.generatedAt}'),
              if (d.status == 'insufficient_data')
                const Text('Chưa đủ dữ liệu'),
              if (d.status == 'failed')
                Text('Đánh giá lỗi: ${d.errorCode ?? 'không rõ'}'),
              ...d.insights.map((i) => Card(
                  child: ListTile(
                      title: Text(i.title),
                      subtitle: Text(i.recommendation),
                      trailing: Text(i.severity))))
            ]);
          }));
}
