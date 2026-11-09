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

  test(
      'selected sample day stays highlighted after sorting without changing records',
      () async {
    final records = (await FigmaMockRepository.exportData())['records'] as List;
    final selected = records.first['date'] as String;
    for (final ascending in [true, false]) {
      final screen = await FigmaMockRepository.usageScreen(
          'M06', Brightness.dark,
          selectedDay: selected, sortBy: 'tokens', ascending: ascending);
      final colored = screen.layers
          .where((l) => l['t'] == 't' && l['c'] == '#ff38d39f')
          .toList();
      expect(colored.length, 3);
      expect(colored.first['v'], '01 Nov');
    }
    final project = await FigmaMockRepository.usageScreen(
        'M06', Brightness.dark,
        selectedDay: selected, grouping: 'Project');
    expect(project.layers.where((l) => l['c'] == '#ff38d39f'), isEmpty);
    expect((await FigmaMockRepository.exportData())['records'], records);
  });

  testWidgets('five Breakdown states match source geometry and Analytics tab',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final nodes = <String>{};
    expect(reviewedStates['M06']!.length, 5);
    for (final state in reviewedStates['M06']!) {
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
      expect(data.hasBackButton, isTrue);
      expect(data.activeTab, 'Analytics');
      expect(tester.getRect(find.byKey(const ValueKey('reviewed-state-card'))),
          const Rect.fromLTWH(20, 142, 350, 260));
      expect(
          tester.getRect(find.byKey(const ValueKey('reviewed-state-action'))),
          const Rect.fromLTWH(20, 708, 350, 52));
      expect(find.byKey(const ValueKey('reviewed-state-back')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture.saveCapture(tester, state.name);
    }
    expect(nodes, {'94:1617', '94:1702', '94:1787', '94:1872', '94:1957'});
  });

  testWidgets('Breakdown picker, day choice, recovery, Back and tabs work',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(appRouter.dispose);
    await tester.runAsync(() async {
      for (final id in [
        'M04',
        'M04B',
        'M05',
        'M06',
        'M07',
        'M09',
        'M10',
        'M14'
      ]) {
        await FigmaMockRepository.screen(id, Brightness.dark);
        await FigmaMockRepository.hotspots(id);
      }
      for (final state in reviewedStates['M06']!) {
        await const AuthMockRepository().getStateData(state);
      }
      await FigmaMockRepository.exportData();
      await FigmaMockRepository.usageScreen('M06', Brightness.dark);
      await FigmaMockRepository.settingsScreen('M10', Brightness.dark);
      await FigmaMockRepository.extraScreen('M14', Brightness.dark);
    });
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp.router(
            theme: ThemeData.dark(), routerConfig: appRouter)));
    Future<void> action() async {
      await tester.runAsync(() =>
          tester.tap(find.byKey(const ValueKey('reviewed-state-action'))));
      await settle(tester);
    }

    for (final state in reviewedStates['M06']!) {
      appRouter.go('/ui-state/${state.name}?period=Week');
      await settle(tester);
      await action();
      if (state == reviewedStates['M06']!.first) {
        expect(find.text('Available dates from sample usage'), findsOneWidget);
        appRouter.pop();
        await settle(tester);
        expect(find.byType(ReviewedStateView), findsOneWidget);
        await action();
        await tester.tap(find.text('2026-11-01'));
        await settle(tester);
        expect(
            tester
                .widget<FigmaPixelScreen>(find.byType(FigmaPixelScreen).last)
                .selectedDay,
            '2026-11-01');
      }
      final expected = state.name == 'breakdownCostUnavailable'
          ? 'M14'
          : state.name == 'breakdownSyncDelayed'
              ? 'M10'
              : 'M06';
      expect(
          tester
              .widget<FigmaPixelScreen>(find.byType(FigmaPixelScreen).last)
              .screenId,
          expected);
      await tester.runAsync(() =>
          tester.tap(find.byKey(const ValueKey('figma-hotspot-Back')).last));
      await settle(tester);
      expect(find.byType(ReviewedStateView), findsOneWidget);
      expect(
          appRouter
              .routeInformationProvider.value.uri.queryParameters['period'],
          'Week');
    }
    await tester.tap(find.byKey(const ValueKey('reviewed-state-back')));
    await settle(tester);
    expect(appRouter.routeInformationProvider.value.uri.path, '/daily-usage');
    expect(
        appRouter.routeInformationProvider.value.uri.queryParameters['period'],
        'Week');
    await tester
        .longPress(find.byKey(const ValueKey('figma-screen-gallery-trigger')));
    await settle(tester);
    await tester.runAsync(() => tester.tap(find.text('M06 - UI states')));
    await settle(tester);
    await tester.runAsync(() => tester.tap(find.text('IN PROGRESS')));
    await settle(tester);
    expect(find.text('Today is still in progress'), findsOneWidget);
    for (var index = 0; index < 4; index++) {
      appRouter.go('/ui-state/breakdownSyncDelayed?period=Week');
      await settle(tester);
      await tester.runAsync(
          () => tester.tap(find.byKey(ValueKey('reviewed-state-tab-$index'))));
      await settle(tester);
      expect(appRouter.routeInformationProvider.value.uri.path,
          ['/tokens', '/analytics', '/insights', '/settings'][index]);
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
