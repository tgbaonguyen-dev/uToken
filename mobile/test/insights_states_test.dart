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
      'six Insights state canvases use source assets, copy and active tab',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final nodes = <String>{};
    expect(reviewedStates['M07']!.length, 6);
    for (final state in reviewedStates['M07']!) {
      final data = (await tester
          .runAsync(() => const AuthMockRepository().getStateData(state)))!;
      final spec = data.figmaLayout!;
      nodes.add(spec['node']);
      for (final path in [
        spec['illustration'],
        spec['divider'],
        ...spec['dots'],
        ...spec['nav']
      ]) {
        expect(File(path).lengthSync(), greaterThan(0));
      }
      expect(data.specificationSubtitle,
          startsWith('State specification \u00b7 '));
      if (data.stateType == 'insufficient_data') {
        expect(data.card.description,
            'Insights require at least 3 days or 10 daily/model records.');
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
                  onTab: (_) {}))));
      await settle(tester);
      expect(data.hasBackButton, isFalse);
      expect(data.activeTab, 'Insights');
      expect(tester.getRect(find.byKey(const ValueKey('reviewed-state-card'))),
          const Rect.fromLTWH(20, 142, 350, 260));
      expect(
          tester.getRect(find.byKey(const ValueKey('reviewed-state-action'))),
          const Rect.fromLTWH(20, 700, 350, 52));
      final label = tester.widget<Text>(find.descendant(
          of: find.byKey(const ValueKey('reviewed-state-tab-2')),
          matching: find.text('Insights')));
      expect(label.style!.color, const Color(0xfff2f3f5));
      expect(tester.takeException(), isNull);
      await capture.saveCapture(tester, state.name);
    }
    expect(nodes,
        {'94:2042', '94:2151', '94:2260', '94:2369', '94:2478', '153:3329'});
  });

  testWidgets(
      'Insights retry, recovery, AI setup, picker and tabs retain period',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(appRouter.dispose);
    Map<String, dynamic>? originalSettings;
    await tester.runAsync(() async {
      for (final id in ['M04', 'M05', 'M07', 'M09', 'M15']) {
        await FigmaMockRepository.screen(id, Brightness.dark);
        await FigmaMockRepository.hotspots(id);
      }
      for (final state in reviewedStates['M07']!) {
        await const AuthMockRepository().getStateData(state);
      }
      await FigmaMockRepository.tokensScreen(Brightness.dark, period: 'Week');
      await FigmaMockRepository.usageScreen('M05', Brightness.dark,
          period: 'Week');
      await FigmaMockRepository.usageScreen('M07', Brightness.dark,
          period: 'Week');
      await FigmaMockRepository.settingsScreen('M09', Brightness.dark);
      await FigmaMockRepository.extraScreen('M15', Brightness.dark);
      originalSettings = await FigmaMockRepository.settingsData();
    });
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp.router(
            theme: ThemeData.dark(), routerConfig: appRouter)));
    Future<void> action() async {
      await tester.runAsync(() =>
          tester.tap(find.byKey(const ValueKey('reviewed-state-action'))));
      await settle(tester);
    }

    for (final state in reviewedStates['M07']!) {
      appRouter.go('/ui-state/${state.name}?period=Week');
      await settle(tester);
      await action();
      if (['insightsAnalysisFailed', 'insightsStale'].contains(state.name)) {
        expect(find.text('Analyzing recent usage'), findsOneWidget);
        expect(
            appRouter
                .routeInformationProvider.value.uri.queryParameters['period'],
            'Week');
        await action();
        expect(appRouter.routeInformationProvider.value.uri.path, '/insights');
      } else if (state.name == 'insightsAiNotSetUp') {
        expect(
            tester
                .widget<FigmaPixelScreen>(find.byType(FigmaPixelScreen).last)
                .screenId,
            'M15');
        await tester.runAsync(() =>
            tester.tap(find.byKey(const ValueKey('figma-hotspot-Back')).last));
        await settle(tester);
        expect(find.text('Choose an AI model'), findsOneWidget);
      } else {
        expect(
            appRouter.routeInformationProvider.value.uri.path,
            state.name == 'insightsInsufficientData'
                ? '/tokens'
                : state.name == 'insightsNoSignificantIssues'
                    ? '/analytics'
                    : '/insights');
      }
      expect(
          appRouter
              .routeInformationProvider.value.uri.queryParameters['period'],
          'Week');
    }
    final afterSettings =
        await tester.runAsync(FigmaMockRepository.settingsData);
    expect(afterSettings, originalSettings);
    appRouter.go('/insights?period=Week');
    await settle(tester);
    await tester
        .longPress(find.byKey(const ValueKey('figma-screen-gallery-trigger')));
    await settle(tester);
    await tester.runAsync(() => tester.tap(find.text('M07 - UI states')));
    await settle(tester);
    await tester.runAsync(() => tester.tap(find.text('ALL CLEAR')));
    await settle(tester);
    expect(find.text('No significant issues found'), findsOneWidget);
    for (var index = 0; index < 4; index++) {
      appRouter.go('/ui-state/insightsStale?period=Week');
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
