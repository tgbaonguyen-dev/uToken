import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:utoken_mobile/app/figma_routes.dart';
import 'package:utoken_mobile/core/mock/figma_mock_repository.dart';
import 'package:utoken_mobile/features/figma/presentation/figma_pixel_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'sync fixtures bind progress, providers and queue without changing usage',
      () async {
    final before = await FigmaMockRepository.tokensScreen(Brightness.dark);
    final waiting =
        await FigmaMockRepository.syncScreen('S02', Brightness.dark);
    expect(waiting.layers[20]['v'], 'Codex');
    expect(waiting.layers[23]['v'], 'Ready');
    final syncing =
        await FigmaMockRepository.syncScreen('S03', Brightness.dark);
    expect(syncing.layers[6]['t'], 'p');
    expect(syncing.layers[6]['progress'], .64);
    expect(syncing.layers[7]['v'], '64%');
    expect(syncing.layers[26]['w'], 172.8);
    final failed = await FigmaMockRepository.syncScreen('S04', Brightness.dark);
    expect(failed.layers[17]['v'], 'Today, 10:42');
    expect(failed.layers[20]['v'], '128 events');
    expect(
        failed.layers
            .where((l) => l['t'] == 'a')
            .every((l) => (l['h'] as num) > 0),
        isTrue);
    final after = await FigmaMockRepository.tokensScreen(Brightness.dark);
    expect(after.layers, before.layers);
  });

  testWidgets('setup, refresh, retry, completion and efficiency routes work',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      for (final id in FigmaMockRepository.screenIds) {
        await FigmaMockRepository.screen(id, Brightness.dark);
        await FigmaMockRepository.hotspots(id);
      }
      for (final id in FigmaMockRepository.syncScreenIds) {
        await FigmaMockRepository.syncScreen(id, Brightness.dark);
      }
      await FigmaMockRepository.tokensScreen(Brightness.dark);
      for (final id in ['M05', 'M05B', 'M05C', 'M07']) {
        await FigmaMockRepository.usageScreen(id, Brightness.dark);
      }
      await FigmaMockRepository.settingsScreen('M10', Brightness.dark);
    });
    final router = GoRouter(initialLocation: '/desktop-not-connected', routes: [
      for (final entry in figmaRoutes.entries)
        GoRoute(
            path: entry.value,
            builder: (_, state) => FigmaPixelScreen(screenId: entry.key))
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(
        MaterialApp.router(theme: ThemeData.dark(), routerConfig: router));
    Future<void> settle() async {
      for (var i = 0; i < 2; i++) {
        await tester.pump();
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)));
        await tester.pumpAndSettle();
      }
    }

    Future<void> tap(String name) async {
      await tester.runAsync(
          () => tester.tap(find.byKey(ValueKey('figma-hotspot-$name')).first));
      await settle();
    }

    await settle();
    await tap('Connect desktop');
    expect(
        tester
            .widget<FigmaPixelScreen>(find.byType(FigmaPixelScreen).last)
            .screenId,
        'M02');
    router.go('/waiting-first-usage');
    await settle();
    await tap('Refresh usage');
    expect(find.text('64%'), findsOneWidget);
    final progress = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator));
    expect(progress.value, .64);
    await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('mock-complete-sync'))));
    await settle();
    expect(router.routeInformationProvider.value.uri.path, '/tokens');
    final settings = await tester.runAsync(FigmaMockRepository.settingsData);
    expect(settings!['lastSync'], 'Just now');
    router.go('/sync-failed');
    await settle();
    await tap('Desktop connection');
    expect(
        tester
            .widget<FigmaPixelScreen>(find.byType(FigmaPixelScreen).last)
            .screenId,
        'M10');
    router.go('/sync-failed');
    await settle();
    await tap('Retry sync');
    expect(
        tester
            .widget<FigmaPixelScreen>(find.byType(FigmaPixelScreen).last)
            .screenId,
        'S03');
    router.go('/efficiency');
    await settle();
    await tap('Compare models');
    expect(
        tester
            .widget<FigmaPixelScreen>(find.byType(FigmaPixelScreen).last)
            .screenId,
        'M05C');
    await tap('Small');
    expect(find.text('BEST FOR SMALL TASKS'), findsOneWidget);
    await tap('Large');
    expect(find.text('BEST FOR LARGE TASKS'), findsOneWidget);
    await tap('Back');
    await tap('See suggestions');
    expect(
        tester
            .widget<FigmaPixelScreen>(find.byType(FigmaPixelScreen).last)
            .screenId,
        'M07');
    expect(tester.takeException(), isNull);
  });
}
