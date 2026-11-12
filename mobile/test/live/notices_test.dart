import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/core/data/local_prefs.dart';
import 'package:utoken_mobile/core/data/cached_usage_repository.dart';
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
    expect(LocalPrefs.instance.isNoticeRead('n2', uid: 'u'), isTrue);
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
    expect(LocalPrefs.instance.isNoticeRead('a', uid: 'u'), isTrue);
    expect(LocalPrefs.instance.isNoticeRead('inbox/b', uid: 'u'), isTrue);
  });

  testWidgets('header bell shows the unread count', (tester) async {
    final repository = FakeUsageRepository()
      ..noticeValues = [notice('x1', 'One'), notice('x2', 'Two')];
    addTearDown(repository.close);
    await tester
        .pumpWidget(app(Scaffold(body: NoticeBell(args: argsFor(repository)))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('icon-badge')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await LocalPrefs.instance.markNoticesRead(['x1', 'x2'], uid: 'u');
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
  test('read state persists independently for each account', () async {
    final store = MemoryPrefsStore();
    store.values['read_notices'] = '["shared"]';
    final prefs = LocalPrefs(store);
    await prefs.load();
    await prefs.loadNoticeReads('alice');
    expect(prefs.isNoticeRead('shared', uid: 'alice'), isFalse);
    await prefs.markNoticesRead(['shared'], uid: 'alice');
    await prefs.loadNoticeReads('bob');
    expect(prefs.isNoticeRead('shared', uid: 'bob'), isFalse);
    final restored = LocalPrefs(store);
    await restored.loadNoticeReads('alice');
    await restored.loadNoticeReads('bob');
    expect(restored.isNoticeRead('shared', uid: 'alice'), isTrue);
    expect(restored.isNoticeRead('shared', uid: 'bob'), isFalse);
    prefs.dispose();
    restored.dispose();
  });

  testWidgets('expiry updates badge without another source event',
      (tester) async {
    var clock = DateTime(2026, 11, 12, 10);
    final repository = FakeUsageRepository()
      ..noticeValues = [
        Notice(
            id: 'expires',
            title: 'Soon',
            body: 'Body',
            level: 'info',
            personal: false,
            expiresAt: clock.add(const Duration(minutes: 1)))
      ];
    addTearDown(repository.close);
    final args = LiveArgs(uid: 'u', repository: repository, now: () => clock);
    await tester.pumpWidget(app(Scaffold(body: NoticeBell(args: args))));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    clock = clock.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('icon-badge')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('permission error is visible and Retry reopens cached source',
      (tester) async {
    final repository = _RetryNoticesRepository();
    addTearDown(repository.close);
    final cached = CachedUsageRepository(repository);
    final args = LiveArgs(uid: 'u', repository: cached);
    await tester.pumpWidget(app(LiveNoticesScreen(args: args)));
    await tester.pumpAndSettle();
    expect(find.text('Could not load notifications'), findsOneWidget);
    expect(find.text('No notifications'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.opens, 2);
    expect(find.text('Recovered'), findsOneWidget);
    expect(find.text('Could not load notifications'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  });
}

class _RetryNoticesRepository extends FakeUsageRepository {
  int opens = 0;
  @override
  Stream<List<Notice>> watchNotices({required String uid}) {
    if (++opens == 1) return Stream.error(Exception('permission-denied'));
    return Stream.value([
      const Notice(
          id: 'ok',
          title: 'Recovered',
          body: 'Body',
          level: 'info',
          personal: false)
    ]);
  }
}
