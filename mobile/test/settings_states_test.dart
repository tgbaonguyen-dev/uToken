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
      'three Settings states match source assets, copy and Settings navigation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    expect(reviewedStates['M09']!.length, 3);
    final nodes = <String>{};
    for (final state in reviewedStates['M09']!) {
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
      if (state.name == 'settingsNotificationsDenied') {
        expect(data.card.description,
            '\u03bcToken cannot display system notifications for budget thresholds.');
        expect(data.card.items.first.title, 'Budgets still calculate');
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
      expect(data.hasBackButton, isFalse);
      expect(tester.getRect(find.byKey(const ValueKey('reviewed-state-card'))),
          const Rect.fromLTWH(20, 142, 350, 260));
      expect(
          tester.getRect(find.byKey(const ValueKey('reviewed-state-action'))),
          const Rect.fromLTWH(20, 700, 350, 52));
      final label = tester.widget<Text>(find.descendant(
          of: find.byKey(const ValueKey('reviewed-state-tab-3')),
          matching: find.text('Settings')));
      expect(label.style!.color, const Color(0xfff2f3f5));
      expect(tester.takeException(), isNull);
      await capture.saveCapture(tester, state.name);
    }
    expect(nodes, {'94:2842', '94:2951', '94:3060'});
  });

  testWidgets(
      'Settings state recovery, Back, picker and tabs leave preferences intact',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(appRouter.dispose);
    Map<String, dynamic>? before;
    await tester.runAsync(() async {
      for (final id in ['M02', 'M04', 'M05', 'M07', 'M09', 'M11', 'M13']) {
        await FigmaMockRepository.screen(id, Brightness.dark);
        await FigmaMockRepository.hotspots(id);
      }
      for (final state in reviewedStates['M09']!) {
        await const AuthMockRepository().getStateData(state);
      }
      for (final id in ['M09', 'M11', 'M13']) {
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
    final destinations = ['M02', 'M11', 'M13'];
    final states = reviewedStates['M09']!;
    for (var index = 0; index < states.length; index++) {
      appRouter.go('/ui-state/${states[index].name}?period=Week');
      await settle(tester);
      await tester.runAsync(() =>
          tester.tap(find.byKey(const ValueKey('reviewed-state-action'))));
      await settle(tester);
      expect(
          tester
              .widget<FigmaPixelScreen>(find.byType(FigmaPixelScreen).last)
              .screenId,
          destinations[index]);
      await tester.runAsync(() =>
          tester.tap(find.byKey(const ValueKey('figma-hotspot-Back')).last));
      await settle(tester);
      expect(find.byType(ReviewedStateView), findsOneWidget);
      expect(
          appRouter
              .routeInformationProvider.value.uri.queryParameters['period'],
          'Week');
    }
    appRouter.go('/settings?period=Week');
    await settle(tester);
    await tester
        .longPress(find.byKey(const ValueKey('figma-screen-gallery-trigger')));
    await settle(tester);
    await tester.runAsync(() => tester.tap(find.text('M09 - UI states')));
    await settle(tester);
    await tester.runAsync(() => tester.tap(find.text('NOTIFICATIONS OFF')));
    await settle(tester);
    expect(find.text('Budget alerts are disabled'), findsOneWidget);
    for (var index = 0; index < 4; index++) {
      appRouter.go('/ui-state/settingsReauthenticationRequired?period=Week');
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
