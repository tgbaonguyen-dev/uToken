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
    if (Platform.isWindows) {
      await (FontLoader('Arial')
            ..addFont(File('C:/Windows/Fonts/arial.ttf')
                .readAsBytes()
                .then((bytes) => ByteData.sublistView(bytes))))
          .load();
    }
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets(
      'six Budget states match source geometry, amounts and Settings navigation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final nodes = <String>{};
    expect(reviewedStates['M11']!.length, 6);
    for (final state in reviewedStates['M11']!) {
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
      expect(data.screenTitle, 'Budget & alerts');
      expect(data.specificationSubtitle,
          startsWith('State specification \u00b7 '));
      if (data.stateType == 'near_threshold') {
        expect(data.card.items.first.title, r'74% of $60 used');
        expect(data.card.items.first.subtitle, r'$15.60 estimated remaining');
        final values = RegExp(r'[0-9.]+')
            .allMatches(data.card.items.first.title)
            .map((m) => double.parse(m.group(0)!))
            .toList();
        final remaining = double.parse(RegExp(r'[0-9.]+')
            .firstMatch(data.card.items.first.subtitle)!
            .group(0)!);
        expect(remaining, closeTo(values[1] * (1 - values[0] / 100), .00001));
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
      expect(data.activeTab, 'Settings');
      expect(data.hasBackButton, isTrue);
      expect(tester.getRect(find.byKey(const ValueKey('reviewed-state-card'))),
          const Rect.fromLTWH(20, 142, 350, 260));
      expect(
          tester.getRect(find.byKey(const ValueKey('reviewed-state-action'))),
          const Rect.fromLTWH(20, 708, 350, 52));
      if (data.stateType == 'cost_unavailable') {
        expect(find.textContaining(r'$0.00'), findsNothing);
        expect(find.text('Thresholds are not evaluated'), findsOneWidget);
      }
      if (data.stateType == 'budget_exceeded') {
        expect(find.text(r'$63.20 of $60 estimated'), findsOneWidget);
        expect(
            find.text('\u03bcToken does not block AI tools'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await capture.saveCapture(tester, state.name);
    }
    expect(nodes,
        {'94:3929', '94:4014', '94:4099', '94:4184', '94:4269', '94:4354'});
  });

  testWidgets(
      'Budget state recovery, draft discard, Back, picker and tabs preserve preferences',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(appRouter.dispose);
    Map<String, dynamic>? before;
    await tester.runAsync(() async {
      for (final id in ['M04', 'M05', 'M07', 'M09', 'M11', 'M14']) {
        await FigmaMockRepository.screen(id, Brightness.dark);
        await FigmaMockRepository.hotspots(id);
      }
      for (final state in reviewedStates['M11']!) {
        await const AuthMockRepository().getStateData(state);
      }
      await FigmaMockRepository.extraScreen('M14', Brightness.dark);
      await FigmaMockRepository.tokensScreen(Brightness.dark, period: 'Week');
      await FigmaMockRepository.usageScreen('M05', Brightness.dark,
          period: 'Week');
      await FigmaMockRepository.usageScreen('M07', Brightness.dark,
          period: 'Week');
      await FigmaMockRepository.settingsScreen('M09', Brightness.dark);
      await FigmaMockRepository.settingsScreen('M11', Brightness.dark);
      before = await FigmaMockRepository.settingsData();
    });
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp.router(
            theme: ThemeData.dark(), routerConfig: appRouter)));
    Future<void> tapKey(String key) async {
      await tester.runAsync(() => tester.tap(find.byKey(ValueKey(key)).last));
      await settle(tester);
    }

    for (final state in reviewedStates['M11']!) {
      appRouter.go('/ui-state/${state.name}?period=Week');
      await settle(tester);
      await tapKey('reviewed-state-action');
      final expected = switch (state.name) {
        'budgetThresholdExceeded' || 'budgetBudgetExceeded' => 'M05',
        'budgetCostUnavailable' => 'M14',
        _ => 'M11',
      };
      expect(
          tester
              .widget<FigmaPixelScreen>(find.byType(FigmaPixelScreen).last)
              .screenId,
          expected);
      if (state.name == 'budgetNoBudget') {
        await tapKey('figma-hotspot-Edit monthly limit');
        await tester.enterText(
            find.byKey(const ValueKey('mock-budget-input')), '60');
        await tester.tap(find.text('Apply'));
        await settle(tester);
        expect(find.text(r'of $60.00'), findsOneWidget);
      }
      if (expected == 'M05') {
        appRouter.pop();
      } else {
        await tapKey('figma-hotspot-Back');
      }
      await settle(tester);
      expect(find.byType(ReviewedStateView), findsOneWidget);
      expect(
          appRouter
              .routeInformationProvider.value.uri.queryParameters['period'],
          'Week');
    }
    expect(await tester.runAsync(FigmaMockRepository.settingsData), before);
    await tapKey('reviewed-state-back');
    expect(appRouter.routeInformationProvider.value.uri.path, '/budget');
    expect(
        appRouter.routeInformationProvider.value.uri.queryParameters['period'],
        'Week');
    await tester
        .longPress(find.byKey(const ValueKey('figma-screen-gallery-trigger')));
    await settle(tester);
    await tester.runAsync(() => tester.tap(find.text('M11 - UI states')));
    await settle(tester);
    await tester.runAsync(() => tester.tap(find.text('NEAR THRESHOLD')));
    await settle(tester);
    expect(find.text(r'74% of $60 used'), findsOneWidget);
    for (var index = 0; index < 4; index++) {
      appRouter.go('/ui-state/budgetCostUnavailable?period=Week');
      await settle(tester);
      await tapKey('reviewed-state-tab-$index');
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
