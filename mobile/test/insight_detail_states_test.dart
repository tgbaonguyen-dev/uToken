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
import 'package:utoken_mobile/features/insights/presentation/insight_detail_screen.dart';

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
      'three detail states match source assets, anchors and evidence copy',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    expect(reviewedStates['M08']!.length, 3);
    final nodes = <String>{};
    for (final state in reviewedStates['M08']!) {
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
      expect(data.activeTab, 'Insights');
      expect(data.hasBackButton, isTrue);
      expect(data.specificationSubtitle,
          startsWith('State specification \u00b7 '));
      expect(tester.getRect(find.byKey(const ValueKey('reviewed-state-card'))),
          const Rect.fromLTWH(20, 142, 350, 260));
      expect(
          tester.getRect(find.byKey(const ValueKey('reviewed-state-action'))),
          const Rect.fromLTWH(20, 708, 350, 52));
      if (state.name == 'insightDetailEvidenceUnavailable') {
        expect(
            find.text('Supporting data isn\u2019t available'), findsOneWidget);
        expect(find.textContaining(r'$8.40'), findsNothing);
        expect(find.text('Mark reviewed'), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await capture.saveCapture(tester, state.name);
    }
    expect(nodes, {'94:2587', '94:2672', '94:2757'});
  });

  testWidgets(
      'detail state picker, recovery, Back and tabs retain period without rewriting evidence',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(appRouter.dispose);
    Map<String, dynamic>? originalEvidence;
    await tester.runAsync(() async {
      for (final id in ['M04', 'M05', 'M07', 'M08', 'M09']) {
        await FigmaMockRepository.screen(id, Brightness.dark);
        await FigmaMockRepository.hotspots(id);
      }
      for (final state in reviewedStates['M08']!) {
        await const AuthMockRepository().getStateData(state);
      }
      await FigmaMockRepository.insightScreen();
      await FigmaMockRepository.tokensScreen(Brightness.dark, period: 'Week');
      await FigmaMockRepository.usageScreen('M05', Brightness.dark,
          period: 'Week');
      await FigmaMockRepository.usageScreen('M07', Brightness.dark,
          period: 'Week');
      await FigmaMockRepository.settingsScreen('M09', Brightness.dark);
      originalEvidence = {
        'layers': (await FigmaMockRepository.insightScreen()).layers
      };
    });
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp.router(
            theme: ThemeData.dark(), routerConfig: appRouter)));
    appRouter.go('/insights?period=Week');
    await settle(tester);
    await tester.runAsync(() => tester.tap(
        find.byKey(const ValueKey('figma-hotspot-Trim repeated context'))));
    await settle(tester);
    expect(
        tester
            .widget<InsightDetailScreen>(find.byType(InsightDetailScreen))
            .initialPeriod,
        'Week');
    expect(find.text('\u2248 \$8.40 / month'), findsOneWidget);
    await tester.longPress(
        find.byKey(const ValueKey('figma-screen-gallery-trigger')).last);
    await settle(tester);
    await tester.runAsync(() => tester.tap(find.text('M08 - UI states')));
    await settle(tester);
    await tester.runAsync(() => tester.tap(find.text('STALE')));
    await settle(tester);
    expect(find.text('This insight may be outdated'), findsOneWidget);
    await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('reviewed-state-back'))));
    await settle(tester);
    expect(
        tester
            .widget<InsightDetailScreen>(find.byType(InsightDetailScreen))
            .initialPeriod,
        'Week');
    for (final state in reviewedStates['M08']!) {
      appRouter.go('/ui-state/${state.name}?period=Week');
      await settle(tester);
      await tester.runAsync(() =>
          tester.tap(find.byKey(const ValueKey('reviewed-state-action'))));
      await settle(tester);
      expect(appRouter.routeInformationProvider.value.uri.path, '/insights');
      expect(
          appRouter
              .routeInformationProvider.value.uri.queryParameters['period'],
          'Week');
    }
    appRouter.go('/ui-state/insightDetailResolved?period=Week');
    await settle(tester);
    await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('reviewed-state-back'))));
    await settle(tester);
    expect(
        appRouter.routeInformationProvider.value.uri.path, '/insight-detail');
    expect(
        tester
            .widget<InsightDetailScreen>(find.byType(InsightDetailScreen))
            .initialPeriod,
        'Week');
    expect(find.text('Active'), findsOneWidget);
    for (var index = 0; index < 4; index++) {
      appRouter.go('/ui-state/insightDetailEvidenceUnavailable?period=Week');
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
    final after = await tester.runAsync(FigmaMockRepository.insightScreen);
    expect(after!.layers, originalEvidence!['layers']);
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
