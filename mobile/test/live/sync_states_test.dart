import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/core/data/usage_repository.dart';
import 'package:utoken_mobile/core/ui/ut_kit.dart';
import 'package:utoken_mobile/features/live/live_common.dart';
import 'package:utoken_mobile/features/live/tokens_screens.dart';

import 'live_screens_test.dart'
    show FakeUsageRepository, dailyDoc, app, exactTotal;

void main() {
  LiveArgs argsFor(FakeUsageRepository r) => LiveArgs(uid: 'u', repository: r);
  final refresh = find.byKey(const ValueKey('figma-hotspot-Refresh'));
  final s03 = find.byKey(const ValueKey('s03-syncing'));
  final s04 = find.byKey(const ValueKey('s04-sync-failed'));

  tearDown(SyncCenter.resetAll);

  testWidgets('refresh shows S03, then S04 after 30 s without a desktop',
      (tester) async {
    final repository = FakeUsageRepository()..autoCompleteSync = false;
    addTearDown(repository.close);
    repository.dailyValues.add(dailyDoc(DateTime.now(), 1200, 2500000));
    await tester.pumpWidget(app(LiveTokensScreen(args: argsFor(repository))));
    await tester.pumpAndSettle();

    await tester.tap(refresh);
    await tester.pump();
    await tester.pump();
    expect(s03, findsOneWidget);
    expect(find.text('Waiting for your desktop…'), findsOneWidget);
    expect(exactTotal(tester), '1,200', reason: 'old data stays visible');

    // A second refresh while one is pending writes no new request.
    await tester.tap(refresh);
    await tester.pump();
    expect(repository.requests, ['req-1']);

    await tester.pump(const Duration(seconds: 31));
    expect(s03, findsNothing);
    expect(s04, findsOneWidget);
    expect(find.textContaining('didn’t respond within 30 seconds'),
        findsOneWidget);
    expect(find.text('Retry sync'), findsOneWidget);
    expect(find.text('Desktop connection'), findsOneWidget);
    expect(exactTotal(tester), '1,200');

    // Retry: desktop picks it up, runs, then finishes.
    await tester.tap(find.text('Retry sync'));
    await tester.pump();
    await tester.pump();
    expect(repository.requests, ['req-1', 'req-2']);
    repository.requestStates['req-2']!
        .add(const SyncRequestStatus(state: 'running'));
    await tester.pump();
    expect(find.text('Syncing usage…'), findsOneWidget);
    repository.requestStates['req-2']!
        .add(const SyncRequestStatus(state: 'done'));
    await tester.pumpAndSettle();
    expect(s03, findsNothing);
    expect(s04, findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a desktop error shows S04 with its reason', (tester) async {
    final repository = FakeUsageRepository()..autoCompleteSync = false;
    addTearDown(repository.close);
    repository.dailyValues.add(dailyDoc(DateTime.now(), 1200, 2500000));
    await tester.pumpWidget(app(LiveTokensScreen(args: argsFor(repository))));
    await tester.pumpAndSettle();
    await tester.tap(refresh);
    await tester.pump();
    await tester.pump();
    repository.requestStates['req-1']!
        .add(const SyncRequestStatus(state: 'failed', errorCode: 'revoked'));
    await tester.pumpAndSettle();
    expect(s04, findsOneWidget);
    expect(
        find.textContaining('Desktop needs to sign in again'), findsOneWidget);
  });

  testWidgets('opening Tokens with old data sends screen_open once',
      (tester) async {
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    repository.dailyValues.add(dailyDoc(DateTime.now(), 1200, 2500000));
    await tester.pumpWidget(app(LiveTokensScreen(args: argsFor(repository))));
    repository.sync.add(DateTime.now().subtract(const Duration(hours: 2)));
    await tester.pumpAndSettle();
    repository.sync.add(DateTime.now().subtract(const Duration(hours: 2)));
    await tester.pumpAndSettle();
    expect(repository.triggers, ['screen_open']);
  });

  testWidgets('fresh data sends nothing; day-old data shows stale banner',
      (tester) async {
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    repository.dailyValues.add(dailyDoc(DateTime.now(), 1200, 2500000));
    await tester.pumpWidget(app(LiveTokensScreen(args: argsFor(repository))));
    repository.sync.add(DateTime.now().subtract(const Duration(minutes: 3)));
    await tester.pumpAndSettle();
    expect(repository.triggers, isEmpty);
    expect(find.byKey(const ValueKey('stale-banner')), findsNothing);

    repository.sync.add(DateTime.now().subtract(const Duration(days: 2)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stale-banner')), findsOneWidget);
    expect(find.text('Data may be out of date'), findsOneWidget);
  });

  testWidgets('offline strip follows the shared offline flag', (tester) async {
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    addTearDown(() => utOffline.value = false);
    repository.dailyValues.add(dailyDoc(DateTime.now(), 1200, 2500000));
    await tester.pumpWidget(app(LiveTokensScreen(args: argsFor(repository))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('offline-strip')), findsNothing);
    utOffline.value = true;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('offline-strip')), findsOneWidget);
    expect(exactTotal(tester), '1,200');
    utOffline.value = false;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('offline-strip')), findsNothing);
  });
}
