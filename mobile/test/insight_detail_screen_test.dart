import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:utoken_mobile/core/mock/figma_mock_repository.dart';
import 'package:utoken_mobile/features/figma/presentation/figma_pixel_screen.dart';
import 'package:utoken_mobile/features/insights/presentation/insight_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('M08 binds content from JSON and original assets remain local',
      () async {
    final active = await FigmaMockRepository.insightScreen();
    final reviewed = await FigmaMockRepository.insightScreen(reviewed: true);
    final texts = active.layers.where((l) => l['t'] == 't').map((l) => l['v']);
    expect(texts, contains('\u2248 \$8.40 / month'));
    expect(texts, contains('18.4K'));
    expect(
        texts,
        contains(
            'Based on aggregate metadata only \u2014 no prompts or source code.'));
    expect(
        texts, contains('Gemini \u00b7 Project Camellya \u00b7 Last 30 days'));
    expect(reviewed.layers.where((l) => l['v'] == 'Reviewed'), hasLength(2));
    expect(active.layers.where((l) => l['v'] == 'Reviewed'), isEmpty);
    for (final layer in active.layers.where((l) => l['t'] == 'a')) {
      final name =
          (layer['id'] as String).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      expect(File('assets/figma/$name.svg').lengthSync(), greaterThan(0));
    }
  });

  testWidgets(
      'M08 matches source anchors and Back/Mark reviewed callbacks work',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      await FigmaMockRepository.insightScreen();
      await FigmaMockRepository.hotspots('M08');
    });
    var backs = 0, reviews = 0;
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: InsightDetailScreen(
            onBack: () => backs++, onMarkReviewed: () => reviews++)));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.text('Insight detail'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Large context is driving token growth'), findsOneWidget);
    expect(
        tester
            .getRect(find.byKey(const ValueKey('figma-hotspot-Mark reviewed'))),
        const Rect.fromLTWH(20, 704, 350, 48));
    expect(tester.getRect(find.byKey(const ValueKey('utoken-tab-2'))),
        const Rect.fromLTWH(195, 776, 97.5, 68));
    await tester.tap(find.byKey(const ValueKey('figma-hotspot-Back')));
    expect(backs, 1);
    await tester.tap(find.byKey(const ValueKey('figma-hotspot-Mark reviewed')));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pumpAndSettle();
    expect(reviews, 1);
    expect(find.text('Reviewed'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('figma-hotspot-Mark reviewed')));
    expect(reviews, 1);
  });

  testWidgets('M08 bottom navigation goes to the chosen main screen',
      (tester) async {
    final router = GoRouter(initialLocation: '/insight-detail', routes: [
      GoRoute(
          path: '/insight-detail',
          builder: (_, __) => const InsightDetailScreen()),
      GoRoute(
          path: '/analytics',
          builder: (_, __) => const FigmaPixelScreen(screenId: 'M05')),
    ]);
    addTearDown(router.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      await FigmaMockRepository.insightScreen();
      await FigmaMockRepository.hotspots('M08');
      await FigmaMockRepository.usageScreen('M05', Brightness.dark);
      await FigmaMockRepository.hotspots('M05');
    });
    await tester.pumpWidget(
        MaterialApp.router(theme: ThemeData.dark(), routerConfig: router));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('utoken-tab-1')));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/analytics');
    expect(find.text('Token mix, models, and cost.'), findsOneWidget);
  });
}
