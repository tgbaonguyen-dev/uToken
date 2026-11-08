import 'dart:convert';
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

  test(
      'export ready, export screen and CSV/JSON previews share the same record count',
      () async {
    final data = await const AuthMockRepository()
        .getStateData(AuthScreenState.privacyExportSuccess);
    final export =
        await FigmaMockRepository.extraScreen('O01', Brightness.dark);
    final json =
        jsonDecode(await FigmaMockRepository.exportPreview('JSON')) as Map;
    final count = (json['records'] as List).length;
    expect(data.card.items.first.title, '$count usage records');
    expect(export.layers[8]['v'], startsWith('$count daily records'));
    expect(
        (await FigmaMockRepository.exportPreview('CSV')).split('\n').length - 1,
        count);
  });

  testWidgets('seven Privacy states match source assets and geometry',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final nodes = <String>{};
    expect(reviewedStates['M12']!.length, 7);
    for (final state in reviewedStates['M12']!) {
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
      expect(data.screenTitle, 'Privacy & data');
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
      expect(tester.takeException(), isNull);
      await capture.saveCapture(tester, state.name);
    }
    expect(nodes, {
      '94:4439',
      '94:4524',
      '94:4609',
      '94:4694',
      '94:4779',
      '94:4864',
      '94:4949'
    });
  });

  testWidgets(
      'Privacy recovery, export previews, mock verification and delete retries keep data intact',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(appRouter.dispose);
    Map<String, dynamic>? beforeSettings;
    String? beforeExport;
    await tester.runAsync(() async {
      for (final id in ['M04', 'M05', 'M07', 'M09', 'M12', 'O01']) {
        await FigmaMockRepository.screen(id, Brightness.dark);
        await FigmaMockRepository.hotspots(id);
      }
      for (final state in reviewedStates['M12']!) {
        await const AuthMockRepository().getStateData(state);
      }
      await FigmaMockRepository.extraScreen('O01', Brightness.dark);
      await FigmaMockRepository.extraData();
      await FigmaMockRepository.tokensScreen(Brightness.dark, period: 'Week');
      await FigmaMockRepository.usageScreen('M05', Brightness.dark,
          period: 'Week');
      await FigmaMockRepository.usageScreen('M07', Brightness.dark,
          period: 'Week');
      await FigmaMockRepository.settingsScreen('M09', Brightness.dark);
      await FigmaMockRepository.settingsScreen('M12', Brightness.dark);
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

    for (final state in reviewedStates['M12']!) {
      appRouter.go('/ui-state/${state.name}?period=Week');
      await settle(tester);
      await tapKey('reviewed-state-action');
      if (state == AuthScreenState.privacyReauthentication ||
          state == AuthScreenState.privacyDeletePartial) {
        final verify = state == AuthScreenState.privacyReauthentication;
        expect(
            find.text(
                verify ? 'Verify with Google (demo)' : 'Remaining data (demo)'),
            findsOneWidget);
        if (!verify) {
          expect(find.textContaining('demo-delete-001'), findsOneWidget);
        }
        await tester.tap(find.text('Cancel'));
        await settle(tester);
        expect(find.byType(ReviewedStateView), findsOneWidget);
        await tapKey('reviewed-state-action');
        await tester.runAsync(() => tester
            .tap(find.text(verify ? 'Simulate verified' : 'Preview retry')));
        await settle(tester);
        expect(
            find.text(verify ? 'Preparing your export' : 'Deleting usage data'),
            findsOneWidget);
        expect(
            appRouter
                .routeInformationProvider.value.uri.queryParameters['period'],
            'Week');
        await tapKey('reviewed-state-action');
      } else if (state == AuthScreenState.privacyExportFailed) {
        expect(find.text('Preparing your export'), findsOneWidget);
        expect(find.text('CSV and JSON requested'), findsOneWidget);
        await tapKey('reviewed-state-action');
      }
      final id = state == AuthScreenState.privacyExportSuccess ? 'O01' : 'M12';
      expect(
          tester
              .widget<FigmaPixelScreen>(find.byType(FigmaPixelScreen).last)
              .screenId,
          id);
      if (id == 'O01') {
        for (final format in ['CSV', 'JSON']) {
          await tapKey('figma-hotspot-Download $format');
          expect(find.text('$format preview (mock)'), findsOneWidget);
          expect(
              find.text('Sample data only. No file is saved.'), findsOneWidget);
          expect(find.byType(SelectableText), findsOneWidget);
          await tester.tap(find.text('Close').last);
          await settle(tester);
        }
      }
      await tapKey('figma-hotspot-Back');
      expect(find.byType(ReviewedStateView), findsOneWidget);
    }
    expect(await tester.runAsync(FigmaMockRepository.settingsData),
        beforeSettings);
    expect(
        await tester.runAsync(() => FigmaMockRepository.exportPreview('JSON')),
        beforeExport);
    await tapKey('reviewed-state-back');
    expect(appRouter.routeInformationProvider.value.uri.path, '/privacy');
    expect(
        appRouter.routeInformationProvider.value.uri.queryParameters['period'],
        'Week');
    await tester
        .longPress(find.byKey(const ValueKey('figma-screen-gallery-trigger')));
    await settle(tester);
    await tester.runAsync(() => tester.tap(find.text('M12 - UI states')));
    await settle(tester);
    await tester.runAsync(() => tester.tap(find.text('EXPORT READY')));
    await settle(tester);
    expect(find.text('Your export is ready'), findsOneWidget);
    for (var index = 0; index < 4; index++) {
      appRouter.go('/ui-state/privacyDeletingUsage?period=Week');
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
