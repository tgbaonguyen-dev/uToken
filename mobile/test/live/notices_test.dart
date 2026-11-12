import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/core/data/local_prefs.dart';
import 'package:utoken_mobile/core/models/usage_docs.dart';
import 'package:utoken_mobile/features/live/live_common.dart';
import 'package:utoken_mobile/features/live/notices.dart';
import 'package:utoken_mobile/features/live/tokens_screens.dart';

import 'live_screens_test.dart' show FakeUsageRepository, dailyDoc, app;

void main() {
  LiveArgs argsFor(FakeUsageRepository r) => LiveArgs(uid: 'u', repository: r);
  final now = DateTime.now();
  Notice notice(String id, String title,
          {int minutesAgo = 0, String level = 'info', bool personal = false}) =>
      Notice(
          id: id,
          title: title,
          body: 'Body of $title',
          level: level,
          personal: personal,
          createdAt: now.subtract(Duration(minutes: minutesAgo)));

  setUp(() => LocalPrefs.instance = LocalPrefs(MemoryPrefsStore()));

  testWidgets('Tokens shows the newest unread notice; Dismiss hides it',
      (tester) async {
    final repository = FakeUsageRepository()
      ..noticeValues = [
        notice('n2', 'Maintenance tonight', level: 'warning'),
        notice('n1', 'Welcome', minutesAgo: 60)
      ];
    addTearDown(repository.close);
    repository.dailyValues.add(dailyDoc(now, 1200, 2500000));
    await tester.pumpWidget(app(LiveTokensScreen(args: argsFor(repository))));
    await tester.pumpAndSettle();
    expect(find.text('Maintenance tonight'), findsOneWidget);
    expect(find.text('View all (2)'), findsOneWidget);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Maintenance tonight'), findsNothing);
    expect(find.text('Welcome'), findsOneWidget);
    expect(LocalPrefs.instance.isNoticeRead('n2'), isTrue);
  });

  testWidgets('opening Notifications lists all and marks them read',
      (tester) async {
    final repository = FakeUsageRepository()
      ..noticeValues = [
        notice('a', 'New version 0.2'),
        notice('inbox/b', 'About your account',
            personal: true, level: 'critical')
      ];
    addTearDown(repository.close);
    await tester.pumpWidget(app(LiveNoticesScreen(args: argsFor(repository))));
    await tester.pumpAndSettle();
    expect(find.text('New version 0.2'), findsOneWidget);
    expect(find.text('About your account'), findsOneWidget);
    expect(find.textContaining('Sent to you'), findsOneWidget);
    expect(LocalPrefs.instance.isNoticeRead('a'), isTrue);
    expect(LocalPrefs.instance.isNoticeRead('inbox/b'), isTrue);
  });

  testWidgets('header bell shows the unread count', (tester) async {
    final repository = FakeUsageRepository()
      ..noticeValues = [notice('x1', 'One'), notice('x2', 'Two')];
    addTearDown(repository.close);
    await tester.pumpWidget(app(Scaffold(body: NoticeBell(args: argsFor(repository)))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('icon-badge')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await LocalPrefs.instance.markNoticesRead(['x1', 'x2']);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('icon-badge')), findsNothing);
  });

  test('expired notices are not live', () {
    final n = Notice(
        id: 'x',
        title: 't',
        body: 'b',
        level: 'info',
        personal: false,
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)));
    expect(n.isLive(DateTime.now()), isFalse);
    expect(
        Notice.fromMap('y', {'title': 'T', 'level': 'bogus'}, personal: true)
            .id,
        'inbox/y');
    expect(
        Notice.fromMap('y', {'title': 'T', 'level': 'bogus'}, personal: true)
            .level,
        'info');
  });
}
