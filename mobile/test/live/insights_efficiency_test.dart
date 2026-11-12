import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:utoken_mobile/features/ai_review/phone_judge.dart';
import 'package:utoken_mobile/features/ai_review/review_window.dart';
import 'package:utoken_mobile/core/data/usage_repository.dart';
import 'package:utoken_mobile/features/live/tokens_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/core/data/local_prefs.dart';
import 'package:utoken_mobile/core/models/usage_docs.dart';
import 'package:utoken_mobile/features/live/analytics_screens.dart';
import 'package:utoken_mobile/features/live/insights_screens.dart';
import 'package:utoken_mobile/features/live/live_common.dart';

import 'live_screens_test.dart' show FakeUsageRepository, app, keyedDoc;

class _ScopeJudge extends PhoneJudge {
  _ScopeJudge() : super(MemoryPrefsStore());
  final scopes = <ReviewScope>[];
  @override
  bool get hasKey => true;
  @override
  Future<void> run(
      {required String uid,
      required UsageRepository repository,
      required String language,
      ReviewScope scope = ReviewScope.last30Days}) async {
    scopes.add(scope);
    step = JudgeStep.done;
    notifyListeners();
  }
}

final _modelReply = {
  'score': 64,
  'grade': 'C',
  'headline': 'Cache is underused.',
  'dimensions': [
    {'id': 'cache', 'score': 40, 'comment': 'Low cache hit rate.'}
  ],
  'insights': [
    {
      'id': 'cache',
      'title': 'Use the cache more',
      'severity': 'high',
      'category': 'cache',
      'provider': 'codex',
      'evidence': [
        {'metric': 'usage.cache_hit_rate'}
      ],
      'recommendation': 'Keep stable context at the start.',
      'estimated_impact': '-20% cost',
      'estimated_saving_usd_per_month': 1.5,
      'confidence': 'medium'
    },
    {
      'id': 'fake',
      'title': 'Invented',
      'severity': 'low',
      'category': 'cache',
      'provider': null,
      'evidence': [
        {'metric': 'made.up'}
      ],
      'recommendation': 'x',
      'estimated_impact': null,
      'estimated_saving_usd_per_month': null,
      'confidence': 'low'
    }
  ]
};

const _review = InsightsDoc(
  status: 'ok',
  generatedAt: '2026-11-11T08:00:00Z',
  headline: 'Caching is strong, but long chats waste context.',
  score: 72,
  grade: 'B',
  periodStart: '2026-10-12',
  periodEnd: '2026-11-10',
  provider: 'anthropic',
  model: 'claude-sonnet',
  dimensions: [
    InsightDimension(id: 'cache', score: 90, comment: 'Most input is cached.'),
    InsightDimension(
        id: 'context', score: 41, comment: 'Chats grow 4× before ending.'),
  ],
  insights: [
    Insight(
        id: 'low',
        title: 'Retry less often',
        severity: 'low',
        category: 'reliability',
        evidence: [
          Evidence(
              metric: 'process.retry_rate', label: 'Retry rate', value: '3%')
        ],
        recommendation: 'Check flaky tests before re-running.',
        confidence: 'medium'),
    Insight(
        id: 'trim',
        title: 'Start fresh chats for new tasks',
        severity: 'high',
        category: 'context',
        provider: 'claude_code',
        evidence: [
          Evidence(
              metric: 'process.context_growth.claude_code',
              label: 'Context growth',
              value: '4.2×')
        ],
        recommendation: 'Open a new chat when the task changes.',
        why: 'Long chats resend the whole history on every turn.',
        steps: ['Run /clear between tasks', 'Keep notes in a file'],
        estimatedSavingMicroPerMonth: 12500000,
        confidence: 'high'),
  ],
);

void main() {
  setUp(() {
    LocalPrefs.instance = LocalPrefs(MemoryPrefsStore());
    PhoneJudge.instance = PhoneJudge(MemoryPrefsStore());
  });
  LiveArgs argsFor(FakeUsageRepository r) => LiveArgs(uid: 'u', repository: r);

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets(
      'the review picker routes both scopes and opening it makes no AI call',
      (tester) async {
    await phone(tester);
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    final judge = _ScopeJudge();
    PhoneJudge.instance = judge;
    addTearDown(judge.dispose);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(app(LiveInsightsScreen(args: argsFor(repository))));
    repository.insights.add(_review);
    await tester.pumpAndSettle();
    expect(judge.scopes, isEmpty);
    for (final entry in [
      ('Review new usage', ReviewScope.sinceLastReview),
      ('Review 30 days', ReviewScope.last30Days),
    ]) {
      await tester.tap(find.text('Run new review'));
      await tester.pumpAndSettle();
      expect(
          judge.scopes.length, entry.$2 == ReviewScope.sinceLastReview ? 0 : 1);
      await tester.tap(find.byKey(ValueKey('figma-hotspot-${entry.$1}')));
      await tester.pumpAndSettle();
      expect(judge.scopes.last, entry.$2);
    }
  });

  testWidgets('insights show score, priorities first and full breakdown',
      (tester) async {
    await phone(tester);
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(app(LiveInsightsScreen(args: argsFor(repository))));
    repository.insights.add(_review);
    await tester.pumpAndSettle();
    expect(find.text('72'), findsOneWidget);
    expect(find.text('Grade B'), findsOneWidget);
    expect(find.text('Run new review'), findsOneWidget);
    expect(find.text('What to fix first'), findsOneWidget);
    // Measure both after scrolling so the comparison shares one offset.
    await tester.scrollUntilVisible(find.text('Retry less often'), 200);
    final high = tester.getTopLeft(
        find.text('Start fresh chats for new tasks', skipOffstage: false));
    final low = tester.getTopLeft(find.text('Retry less often'));
    expect(high.dy < low.dy, isTrue);
    await tester.scrollUntilVisible(
        find.text('Chats grow 4× before ending.'), 200);
    expect(find.text('Chats grow 4× before ending.'), findsOneWidget);
  });

  testWidgets('insight detail explains evidence, score and tool usage',
      (tester) async {
    await phone(tester);
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    repository.dailyValues.add(keyedDoc(DateTime.now(), {
      'claude_code|sonnet|none': 3000,
      'claude_code|opus|k1': 1000,
      'codex|gpt-5|k1': 9000,
    }));
    repository.projectNames = {'k1': 'uToken'};
    await tester.pumpWidget(app(
        LiveInsightDetailScreen(args: argsFor(repository), insightId: 'trim')));
    repository.insights.add(_review);
    await tester.pumpAndSettle();
    expect(find.text('What to do'), findsOneWidget);
    expect(find.text('Long chats resend the whole history on every turn.'),
        findsOneWidget);
    expect(find.text('Run /clear between tasks'), findsOneWidget);
    // Contributors come from this tool only (Codex excluded), with names.
    await tester.scrollUntilVisible(find.text('Top projects'), 200);
    expect(find.text('sonnet'), findsOneWidget);
    expect(find.text('gpt-5'), findsNothing);
    expect(find.text('uToken'), findsOneWidget);
    expect(find.text('\$150.00'), findsOneWidget); // yearly saving
    await tester.scrollUntilVisible(find.text('Claude · last 30 days'), 200);
    expect(find.text('Why this was flagged'), findsOneWidget);
    expect(find.text('4.2×'), findsOneWidget);
    expect(find.text('Context score'), findsOneWidget);
  });

  testWidgets('without a key, run review offers setup or the computer',
      (tester) async {
    await phone(tester);
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(app(LiveInsightsScreen(args: argsFor(repository))));
    repository.insights.add(_review);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Run new review'));
    await tester.pumpAndSettle();
    expect(find.text('Add API key'), findsOneWidget);
    await tester.tap(find.text('Ask my computer instead'));
    await tester.pumpAndSettle();
    expect(repository.triggers, ['ai_review']);
  });

  testWidgets('phone review writes insights, then switching tabs is safe',
      (tester) async {
    await phone(tester);
    final repository = FakeUsageRepository();
    repository.efficiencyStream = Stream.value(null);
    addTearDown(repository.close);
    final now = DateTime.now();
    for (var i = 0; i < 4; i++) {
      repository.dailyValues.add(keyedDoc(
          now.subtract(Duration(days: i)), {'codex|gpt-5|none': 2000}));
    }
    PhoneJudge.instance = PhoneJudge(MemoryPrefsStore(),
        client: MockClient((req) async => http.Response(
            jsonEncode({
              'candidates': [
                {
                  'finishReason': 'STOP',
                  'content': {
                    'parts': [
                      {'text': jsonEncode(_modelReply)}
                    ]
                  }
                }
              ]
            }),
            200)));
    await PhoneJudge.instance
        .save(provider: 'google', model: 'gemini-x', apiKey: 'k');
    final args = argsFor(repository);
    final router = GoRouter(initialLocation: '/insights', routes: [
      GoRoute(
          path: '/insights',
          builder: (_, __) => LiveInsightsScreen(args: args)),
      GoRoute(
          path: '/tokens', builder: (_, __) => LiveTokensScreen(args: args)),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    repository.insights.add(null);
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    repository.efficiency.add(null);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    // Opening Insights never starts a paid call before the user chooses a scope.
    expect(repository.savedInsights, isEmpty);
    await tester.tap(find.text('Run AI review'));
    await tester.pumpAndSettle();
    expect(find.text('Since last successful review'), findsOneWidget);
    await tester.tap(find.text('Last 30 days'));
    await tester.pumpAndSettle();
    expect(repository.savedInsights.single['status'], 'ok');
    expect(find.text('Use the cache more'), findsOneWidget);
    // The invented metric was dropped; the real one kept the brief's value.
    final insights = repository.savedInsights.single['insights'] as List;
    expect(insights, hasLength(1));
    await tester.tap(find.byKey(const ValueKey('utoken-tab-0')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('efficiency shows outcome mix, reliability and per-tool table',
      (tester) async {
    await phone(tester);
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    repository.dailyValues.add(keyedDoc(DateTime.now(), {
      'codex|gpt-5|none': 2000
    }, states: {
      'verified_success': 6,
      'likely_failure': 2,
      'undetermined': 2
    }));
    await tester
        .pumpWidget(app(LiveEfficiencyScreen(args: argsFor(repository))));
    repository.efficiency.add(const EfficiencyDoc(
      periodStart: '2026-10-12',
      periodEnd: '2026-11-10',
      generatedAt: '',
      processMetrics: [
        ProcessMetric(metric: 'cache_hit_rate', label: 'good', value: 0.8),
        ProcessMetric(
            metric: 'cache_hit_rate',
            label: 'review',
            provider: 'codex',
            value: 0.4),
      ],
      setups: [
        SetupMetric(
            provider: 'codex',
            model: 'gpt-5',
            taskGroup: 'medium',
            tasks: 30,
            verdict: 'better',
            crossTool: false,
            sr: 0.7,
            cpstMicro: 500000),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('How chats ended'), findsOneWidget);
    expect(find.text('Verified success'), findsOneWidget);
    expect(find.text('75%'), findsWidgets); // 6 of 8 decided chats
    await tester.scrollUntilVisible(find.text('By tool'), 300);
    expect(find.text('Process health'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget); // codex cache hit
    expect(find.text('30 chats · 1 model · \$0.50 / success'), findsOneWidget);
  });
}
