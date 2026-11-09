import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/app/router.dart';
import 'package:utoken_mobile/core/mock/figma_mock_repository.dart';
import 'package:utoken_mobile/features/auth/data/auth_mock_repository.dart';
import 'package:utoken_mobile/features/auth/domain/signing_in_state_model.dart';
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

  testWidgets('five Account states match source assets, copy and geometry',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final nodes = <String>{};
    expect(reviewedStates['M13']!.length, 5);
    for (final state in reviewedStates['M13']!) {
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
      expect(data.screenTitle, 'Account');
      expect(data.specificationSubtitle,
          startsWith('State specification \u00b7 '));
      if (state == AuthScreenState.accountReauthentication) {
        expect(data.card.items.first.title, 'Profile remains signed in');
      }
      if (state == AuthScreenState.accountSigningOut) {
        expect(data.card.items.first.title, 'Cloud data is retained');
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
      expect(tester.takeException(), isNull);
      await capture.saveCapture(tester, state.name);
    }
    expect(nodes, {'94:5034', '94:5119', '94:5204', '94:5289', '94:5374'});
  });

  testWidgets(
      'Account mock verification, sign-out, deletion status/retry and navigation keep data intact',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(appRouter.dispose);
    Map<String, dynamic>? beforeSettings;
    String? beforeExport;
    await tester.runAsync(() async {
      for (final id in ['M01', 'M04', 'M05', 'M07', 'M09', 'M13']) {
        await FigmaMockRepository.screen(id, Brightness.dark);
        await FigmaMockRepository.hotspots(id);
      }
      for (final state in reviewedStates['M13']!) {
        await const AuthMockRepository().getStateData(state);
      }
      await FigmaMockRepository.extraData();
      await FigmaMockRepository.tokensScreen(Brightness.dark, period: 'Week');
      await FigmaMockRepository.usageScreen('M05', Brightness.dark,
          period: 'Week');
      await FigmaMockRepository.usageScreen('M07', Brightness.dark,
          period: 'Week');
      await FigmaMockRepository.settingsScreen('M09', Brightness.dark);
      await FigmaMockRepository.settingsScreen('M13', Brightness.dark);
      beforeSettings = await FigmaMockRepository.settingsData();
      beforeExport = await FigmaMockRepository.exportPreview('JSON');
    });
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp.router(
            theme: ThemeData.dark(), routerConfig: appRouter)));
    Future<void> tapKey(String key) async {
      await tester.runAsync(() => tester.tap(find.byKey(ValueKey(key)).last));
      await settle(tester);
    }

    for (final state in reviewedStates['M13']!) {
      appRouter.go('/ui-state/${state.name}?period=Week');
      await settle(tester);
      await tapKey('reviewed-state-action');
      if (state == AuthScreenState.accountSigningOut) {
        expect(appRouter.routeInformationProvider.value.uri.path, '/welcome');
        expect(
            tester
                .widget<FigmaPixelScreen>(find.byType(FigmaPixelScreen))
                .screenId,
            'M01');
        continue;
      }
      if (state == AuthScreenState.accountReauthentication ||
          state == AuthScreenState.accountDeleteFailed) {
        final verify = state == AuthScreenState.accountReauthentication;
        expect(
            find.text(verify
                ? 'Verify account (demo)'
                : 'Retry account deletion (demo)'),
            findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await settle(tester);
        expect(find.byType(ReviewedStateView), findsOneWidget);
        await tapKey('reviewed-state-action');
        await tester.runAsync(() => tester
            .tap(find.text(verify ? 'Simulate verified' : 'Preview retry')));
        await settle(tester);
        if (verify) {
          expect(
              tester
                  .widget<FigmaPixelScreen>(find.byType(FigmaPixelScreen).last)
                  .screenId,
              'M13');
          await tapKey('figma-hotspot-Back');
          expect(find.text('Confirm it\u2019s you'), findsOneWidget);
        } else {
          expect(find.text('Deleting your account'), findsOneWidget);
          await tapKey('reviewed-state-action');
          expect(find.text('Account deletion status (demo)'), findsOneWidget);
          await tester.tap(find.text('Close'));
          await settle(tester);
        }
      } else {
        expect(find.textContaining('demo-account-delete-001'), findsOneWidget);
        if (state == AuthScreenState.accountDeletePartial) {
          expect(find.textContaining('Usage summaries: needs cleanup'),
              findsOneWidget);
          expect(find.textContaining('Device session records: requires review'),
              findsOneWidget);
        } else {
          expect(find.textContaining('Cloud account data: cleanup pending'),
              findsOneWidget);
        }
        await tester.tap(find.text('Close'));
        await settle(tester);
        expect(find.byType(ReviewedStateView), findsOneWidget);
      }
    }
    expect(await tester.runAsync(FigmaMockRepository.settingsData),
        beforeSettings);
    expect(
        await tester.runAsync(() => FigmaMockRepository.exportPreview('JSON')),
        beforeExport);
    await tapKey('reviewed-state-back');
    expect(appRouter.routeInformationProvider.value.uri.path, '/account');
    expect(
        appRouter.routeInformationProvider.value.uri.queryParameters['period'],
        'Week');
    await tester
        .longPress(find.byKey(const ValueKey('figma-screen-gallery-trigger')));
    await settle(tester);
    await tester.runAsync(() => tester.tap(find.text('M13 - UI states')));
    await settle(tester);
    await tester.runAsync(() => tester.tap(find.text('SIGNING OUT')));
    await settle(tester);
    expect(find.text('Signing out of this phone'), findsOneWidget);
    for (var index = 0; index < 4; index++) {
      appRouter.go('/ui-state/accountReauthentication?period=Week');
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
