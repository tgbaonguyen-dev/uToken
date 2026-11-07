import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:utoken_mobile/app/figma_routes.dart';
import 'package:utoken_mobile/core/mock/figma_mock_repository.dart';
import 'package:utoken_mobile/features/figma/presentation/figma_pixel_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all 24 original Figma frames and prototype destinations are mapped',
      () async {
    expect(figmaRoutes.length, 24);
    expect(FigmaMockRepository.screenIds.toSet(), figmaRoutes.keys.toSet());

    final graph = jsonDecode(await rootBundle.loadString(
      'lib/core/mock/data/figma_verified_prototype_graph.json',
    )) as Map<String, dynamic>;
    expect(graph.length, 24);
    final nav = jsonDecode(await rootBundle.loadString(
      'lib/core/mock/data/figma_navigation_targets.json',
    )) as Map<String, dynamic>;
    final actualRoutes = nav['routes'] as Map<String, dynamic>;

    for (final entry in graph.entries) {
      final id = entry.key;
      expect(figmaRoutes.containsKey(id), isTrue, reason: id);
      final source = entry.value as Map<String, dynamic>;
      final spots = source['spots'] as List;
      final fromNav = actualRoutes[id] as Map<String, dynamic>;
      for (final item in spots) {
        final link = item as Map<String, dynamic>;
        for (final destination in link['targets'] as List) {
          expect(figmaRoutes.containsKey(destination), isTrue, reason: id);
          final actual = fromNav[link['name']];
          expect(
            actual == destination || (id == 'O03' && actual == '@pop'),
            isTrue,
            reason: '$id / ${link['name']} / $destination',
          );
        }
      }
    }
  });

  testWidgets('all four bottom tabs switch the real routes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/tokens',
      routes: [
        for (final item in figmaRoutes.entries)
          GoRoute(
            path: item.value,
            builder: (context, state) => FigmaPixelScreen(screenId: item.key),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.runAsync(() async {
      for (final id in ['M04', 'M05', 'M07', 'M09']) {
        await FigmaMockRepository.screen(id, Brightness.light);
        await FigmaMockRepository.hotspots(id);
      }
      await FigmaMockRepository.demoInteractions();
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 70)));
    await tester.pumpAndSettle();
    for (final (tab, path, label) in [
      (1, '/analytics', 'Token mix, models, and cost.'),
      (2, '/insights', 'Small changes based on your usage.'),
      (3, '/settings', 'Account, display, and sync preferences.'),
      (0, '/tokens', 'Total tokens'),
    ]) {
      final finder = find.byKey(ValueKey('utoken-tab-$tab'));
      expect(finder, findsOneWidget, reason: path);
      expect(tester.getRect(finder).height, greaterThan(45));
      await tester.tap(finder);
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, path);
      expect(find.text(label), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('screen index opens missing S01 Figma state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/tokens',
      routes: [
        for (final item in figmaRoutes.entries)
          GoRoute(
            path: item.value,
            builder: (context, state) => FigmaPixelScreen(screenId: item.key),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.runAsync(() async {
      for (final id in FigmaMockRepository.screenIds) {
        await FigmaMockRepository.screen(id, Brightness.light);
        await FigmaMockRepository.hotspots(id);
      }
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 75)));
    await tester.pumpAndSettle();
    await tester
        .longPress(find.byKey(const ValueKey('figma-screen-gallery-trigger')));
    await tester.pumpAndSettle();
    expect(find.text('All 24 Figma screens'), findsOneWidget);
    final screen = find.text('S01');
    await tester.ensureVisible(screen);
    await tester.tap(screen);
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path,
        '/desktop-not-connected');
    expect(tester.takeException(), isNull);
  });
}
