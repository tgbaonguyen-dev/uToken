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
import 'support/screen_finder.dart';

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
      'eight connection states match source geometry, copy and Settings tab',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final nodes = <String>{};
    expect(reviewedStates['M10']!.length, 8);
    for (final state in reviewedStates['M10']!) {
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
      final label = tester.widget<Text>(find.descendant(
          of: find.byKey(const ValueKey('reviewed-state-tab-3')),
          matching: find.text('Settings')));
      expect(label.style!.color, const Color(0xfff2f3f5));
      expect(tester.takeException(), isNull);
      await capture.saveCapture(tester, state.name);
    }
    expect(nodes, {
      '94:3169',
      '94:3254',
      '94:3339',
      '94:3424',
      '94:3509',
      '94:3594',
      '94:3679',
      '94:3764'
    });
  });

  testWidgets(
      'connection retries, help, pairing, guides, empty usage and picker work without changing data',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(appRouter.dispose);
    Map<String, dynamic>? before;
    await tester.runAsync(() async {
      for (final id in [
        'M02',
        'M03',
        'M04',
        'M05',
        'M07',
        'M09',
        'M10',
        'S02'
      ]) {
        await FigmaMockRepository.screen(id, Brightness.dark);
        await FigmaMockRepository.hotspots(id);
      }
      for (final state in reviewedStates['M10']!) {
        await const AuthMockRepository().getStateData(state);
      }
      await FigmaMockRepository.syncScreen('S02', Brightness.dark);
      await FigmaMockRepository.extraData();
      for (final id in ['M09', 'M10']) {
        await FigmaMockRepository.settingsScreen(id, Brightness.dark);
      }
      await FigmaMockRepository.tokensScreen(Brightness.dark, period: 'Week');
      await FigmaMockRepository.usageScreen('M05', Brightness.dark,
          period: 'Week');
      await FigmaMockRepository.usageScreen('M07', Brightness.dark,
          period: 'Week');
      before = await FigmaMockRepository.settingsData();
    });
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp.router(
            theme: ThemeData.dark(), routerConfig: appRouter)));
    Future<void> action() async {
      await tester.runAsync(() =>
          tester.tap(find.byKey(const ValueKey('reviewed-state-action'))));
      await settle(tester);
    }

    for (final state in reviewedStates['M10']!) {
      appRouter.go('/ui-state/${state.name}?period=Week');
      await settle(tester);
      await action();
      if (state.name == 'desktopConnectionPermissionDenied') {
        expect(find.text('Permission help (demo)'), findsOneWidget);
        expect(find.textContaining('This preview does not change permissions.'),
            findsOneWidget);
        await tester.tap(find.text('Close'));
        await settle(tester);
        expect(find.text('Usage permission is blocked'), findsOneWidget);
        continue;
      }
      if (['desktopConnectionOffline', 'desktopConnectionSyncFailed']
          .contains(state.name)) {
        expect(find.text('Syncing from desktop'), findsOneWidget);
        expect(
            appRouter
                .routeInformationProvider.value.uri.queryParameters['period'],
            'Week');
        await action();
      }
      final expected = switch (state.name) {
        'desktopConnectionSourceNotFound' ||
        'desktopConnectionIncompatibleVersion' =>
          'M03',
        'desktopConnectionSessionRevoked' => 'M02',
        'desktopConnectionNoUsage' => 'S02',
        _ => 'M10',
      };
      expect(topScreenId(tester), expected);
      if (expected == 'S02') {
        expect(find.text('Waiting for first activity'), findsOneWidget);
        expect(find.text('Total tokens'), findsNothing);
        appRouter.pop();
      } else {
        await tester.runAsync(() =>
            tester.tap(find.byKey(const ValueKey('figma-hotspot-Back')).last));
      }
      await settle(tester);
      expect(find.byType(ReviewedStateView), findsOneWidget);
    }
    appRouter.go('/ui-state/desktopConnectionSyncing?period=Week');
    await settle(tester);
    await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('reviewed-state-back'))));
    await settle(tester);
    expect(appRouter.routeInformationProvider.value.uri.path,
        '/desktop-connection');
    expect(
        appRouter.routeInformationProvider.value.uri.queryParameters['period'],
        'Week');
    await tester
        .longPress(find.byKey(const ValueKey('figma-screen-gallery-trigger')));
    await settle(tester);
    await tester.runAsync(() => tester.tap(find.text('M10 - UI states')));
    await settle(tester);
    await tester.runAsync(() => tester.tap(find.text('OFFLINE')));
    await settle(tester);
    expect(find.text('Desktop companion is offline'), findsOneWidget);
    for (var index = 0; index < 4; index++) {
      appRouter.go('/ui-state/desktopConnectionSessionRevoked?period=Week');
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
    expect(await tester.runAsync(FigmaMockRepository.settingsData), before);
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
