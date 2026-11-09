import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/app/router.dart';
import 'package:utoken_mobile/core/mock/figma_mock_repository.dart';
import 'package:utoken_mobile/features/auth/data/auth_mock_repository.dart';
import 'package:utoken_mobile/features/auth/presentation/reviewed_state_navigation.dart';
import 'package:utoken_mobile/features/auth/presentation/reviewed_state_view.dart';
import 'package:utoken_mobile/features/figma/presentation/figma_pixel_screen.dart';

import 'dark_main_review_test.dart' as capture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('BeVietnamPro');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/BeVietnamPro-$weight.ttf'));
    }
    await font.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets(
      'seven Analytics state canvases match source anchors and active tab',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final states = reviewedStates['M05']!;
    expect(states.length, 7);
    final nodes = <String>{};
    for (final state in states) {
      final data = (await tester
          .runAsync(() => const AuthMockRepository().getStateData(state)))!;
      final spec = data.figmaLayout!;
      nodes.add(spec['node']);
      expect(data.activeTab, 'Analytics');
      for (final path in [
        spec['illustration'],
        spec['divider'],
        ...spec['dots'],
        ...spec['nav']
      ]) {
        expect(File(path).lengthSync(), greaterThan(0), reason: path);
      }
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData.dark(),
          home: RepaintBoundary(
            key: const ValueKey('capture'),
            child: ReviewedStateView(
                data: data,
                onAction: () {},
                onBack: () {},
                onSelectState: () {},
                onTab: (_) {}),
          )));
      await settle(tester);
      expect(tester.getRect(find.byKey(const ValueKey('reviewed-state-card'))),
          const Rect.fromLTWH(20, 142, 350, 260));
      expect(
          tester.getRect(find.byKey(const ValueKey('reviewed-state-action'))),
          const Rect.fromLTWH(20, 700, 350, 52));
      final navLabel = tester.widget<Text>(find.descendant(
          of: find.byKey(const ValueKey('reviewed-state-tab-1')),
          matching: find.text('Analytics')));
      expect(navLabel.style!.color, const Color(0xfff2f3f5));
      expect(tester.takeException(), isNull, reason: state.name);
      await capture.saveCapture(tester, state.name);
    }
    expect(nodes, {
      '94:854',
      '94:963',
      '94:1072',
      '94:1181',
      '94:1290',
      '94:1399',
      '94:1508'
    });
  });

  testWidgets(
      'Analytics state recovery, range selection, tabs and picker retain period',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(appRouter.dispose);
    await tester.runAsync(() async {
      for (final id in ['M04', 'M05', 'M07', 'M09']) {
        await FigmaMockRepository.screen(id, Brightness.dark);
        await FigmaMockRepository.hotspots(id);
      }
      await FigmaMockRepository.tokensScreen(Brightness.dark, period: 'Week');
      await FigmaMockRepository.usageScreen('M05', Brightness.dark,
          period: 'Week');
      await FigmaMockRepository.usageScreen('M07', Brightness.dark,
          period: 'Week');
      await FigmaMockRepository.settingsScreen('M09', Brightness.dark);
      for (final state in reviewedStates['M05']!) {
        await const AuthMockRepository().getStateData(state);
      }
    });
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp.router(
            theme: ThemeData.dark(), routerConfig: appRouter)));
    for (final state in reviewedStates['M05']!) {
      appRouter.go('/ui-state/${state.name}?period=Week');
      await settle(tester);
      expect(find.byType(ReviewedStateView), findsOneWidget);
      await tester.runAsync(() =>
          tester.tap(find.byKey(const ValueKey('reviewed-state-action'))));
      await settle(tester);
      if (state == reviewedStates['M05']!.first) {
        expect(
            find.text('Load sample analytics for this range'), findsOneWidget);
        await tester.tap(find.text('Total'));
        await settle(tester);
        expect(
            appRouter
                .routeInformationProvider.value.uri.queryParameters['period'],
            'Total');
      } else {
        expect(
            appRouter
                .routeInformationProvider.value.uri.queryParameters['period'],
            'Week');
      }
      expect(appRouter.routeInformationProvider.value.uri.path, '/analytics');
      expect(
          tester
              .widget<FigmaPixelScreen>(find.byType(FigmaPixelScreen))
              .screenId,
          'M05');
    }
    for (var index = 0; index < 4; index++) {
      appRouter.go('/ui-state/analyticsOffline?period=Week');
      await settle(tester);
      await tester.runAsync(
          () => tester.tap(find.byKey(ValueKey('reviewed-state-tab-$index'))));
      await settle(tester);
      expect(appRouter.routeInformationProvider.value.uri.path,
          ['/tokens', '/analytics', '/insights', '/settings'][index]);
      if (index < 3) {
        expect(
            appRouter
                .routeInformationProvider.value.uri.queryParameters['period'],
            'Week');
      }
    }
    appRouter.go('/analytics?period=Week');
    await settle(tester);
    await tester
        .longPress(find.byKey(const ValueKey('figma-screen-gallery-trigger')));
    await settle(tester);
    await tester.runAsync(() => tester.tap(find.text('M05 - UI states')));
    await settle(tester);
    await tester.runAsync(() => tester.tap(find.text('NO RESULTS')));
    await settle(tester);
    expect(find.text('No results match these filters'), findsOneWidget);
    expect(
        tester
            .widget<ReviewedStateView>(find.byType(ReviewedStateView))
            .data
            .activeTab,
        'Analytics');
    expect(tester.takeException(), isNull);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 2; i++) {
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pumpAndSettle();
  }
}
