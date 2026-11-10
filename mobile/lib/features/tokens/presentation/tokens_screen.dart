import 'package:flutter/material.dart';
import '../../../core/data/stream_status.dart';
import '../../../core/data/usage_repository.dart';
import '../../../core/models/daily_doc.dart';
import '../../../core/widgets/real_screen_scaffold.dart';
import '../domain/token_dashboard.dart';
import 'widgets/provider_breakdown_section.dart';
import 'widgets/token_summary_section.dart';
import 'widgets/token_trend_section.dart';
import 'widgets/top_models_section.dart';

/// Firestore-backed token dashboard. Aggregation lives in the domain layer.
class TokensScreen extends StatefulWidget {
  const TokensScreen({super.key, required this.uid, required this.repository});
  final String uid;
  final UsageRepository repository;
  @override
  State<TokensScreen> createState() => _TokensScreenState();
}

class _TokensScreenState extends State<TokensScreen> {
  TokenPeriod _period = TokenPeriod.month;
  late Stream<List<DailyDoc>> _dailyStream;
  @override
  void initState() {
    super.initState();
    _dailyStream = _watchDaily();
  }

  @override
  void didUpdateWidget(covariant TokensScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid ||
        oldWidget.repository != widget.repository) {
      _dailyStream = _watchDaily();
    }
  }

  Stream<List<DailyDoc>> _watchDaily() {
    final now = DateTime.now();
    return widget.repository.watchDaily(
        uid: widget.uid,
        start: now.subtract(const Duration(days: 365)),
        end: now);
  }

  @override
  Widget build(BuildContext context) => RealScreenScaffold(
        title: 'Tokens',
        selectedIndex: 0,
        body: StreamBuilder<List<DailyDoc>>(
          stream: _dailyStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text(friendlyStreamError(snapshot.error!)));
            }
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = TokenDashboard.filterPeriod(
                snapshot.data ?? const <DailyDoc>[], _period, DateTime.now());
            final dashboard = TokenDashboard.fromDailyDocs(docs);
            return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  SegmentedButton<TokenPeriod>(
                    segments: const [
                      ButtonSegment(value: TokenPeriod.day, label: Text('Day')),
                      ButtonSegment(
                          value: TokenPeriod.week, label: Text('Week')),
                      ButtonSegment(
                          value: TokenPeriod.month, label: Text('Month')),
                      ButtonSegment(
                          value: TokenPeriod.total, label: Text('Total')),
                    ],
                    selected: {_period},
                    onSelectionChanged: (value) =>
                        setState(() => _period = value.first),
                  ),
                  const SizedBox(height: 12),
                  TokenSummarySection(dashboard: dashboard),
                  const SizedBox(height: 12),
                  ProviderBreakdownSection(dashboard: dashboard),
                  const SizedBox(height: 12),
                  TokenTrendSection(points: dashboard.daily),
                  const SizedBox(height: 12),
                  TopModelsSection(models: dashboard.models),
                ]);
          },
        ),
      );
}
