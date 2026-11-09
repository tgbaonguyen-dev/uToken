import 'package:flutter/material.dart';

import '../../../core/data/usage_repository.dart';
import '../../../core/data/stream_status.dart';
import '../../../core/models/usage_docs.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/real_screen_scaffold.dart';

/// M05B model setup comparison dashboard.
class EfficiencyScreen extends StatelessWidget {
  const EfficiencyScreen(
      {super.key, required this.uid, required this.repository});
  final String uid;
  final UsageRepository repository;

  @override
  Widget build(BuildContext context) => RealScreenScaffold(
        title: 'Efficiency',
        selectedIndex: 1,
        body: StreamBuilder<EfficiencyDoc?>(
          stream: repository.watchEfficiency(uid: uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text(friendlyStreamError(snapshot.error!)));
            }
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final document = snapshot.data;
            if (document == null) {
              return const Center(child: Text('Không có dữ liệu'));
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Model setups', style: AppTypography.cardTitle),
                      ...document.setups.map(_SetupCard.new),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
}

class _SetupCard extends StatelessWidget {
  const _SetupCard(this.setup);
  final SetupMetric setup;

  @override
  Widget build(BuildContext context) {
    final verdict = setup.verdict == 'insufficient'
        ? 'Chưa đủ dữ liệu · ${setup.tasks}/20'
        : setup.verdict;
    final cpst = setup.cpstMicro == null
        ? '—'
        : '\$${(setup.cpstMicro! / 1e6).toStringAsFixed(4)}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${setup.model} · ${setup.taskGroup}'),
      subtitle: Text(
        'SR ${setup.sr == null ? '—' : '${(setup.sr! * 100).toStringAsFixed(1)}%'}  ·  CPST $cpst',
        style: AppTypography.bulletSubtitle,
      ),
      trailing: Chip(
        label: Text(verdict),
        labelStyle: AppTypography.bulletSubtitle,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
