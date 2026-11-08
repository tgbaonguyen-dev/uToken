import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/app/router.dart';
import 'package:utoken_mobile/core/mock/figma_mock_repository.dart';
import 'package:utoken_mobile/features/auth/data/auth_mock_repository.dart';
import 'package:utoken_mobile/features/auth/presentation/reviewed_state_navigation.dart';
import 'package:utoken_mobile/features/figma/presentation/figma_pixel_screen.dart';

import 'account_states_test.dart' show settle;

void main() {
  testWidgets('early state recovery follows button intent and retains period',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(appRouter.dispose);
    await tester.runAsync(() async {
      for (final id in ['M02', 'M03', 'M04']) {
        for (final state in reviewedStates[id]!) {
          await const AuthMockRepository().getStateData(state);
        }
      }
      await FigmaMockRepository.extraData();
      for (final id in [
        'M02',
        'M03',
        'M04',
        'M09',
        'M10',
        'M14',
        'S02',
        'S03'
      ]) {
        await FigmaMockRepository.screen(id, Brightness.dark);
        await FigmaMockRepository.hotspots(id);
      }
      await FigmaMockRepository.tokensScreen(Brightness.dark, period: 'Week');
      await FigmaMockRepository.settingsScreen('M10', Brightness.dark);
      await FigmaMockRepository.demoInteractions();
    });
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp.router(
            theme: ThemeData.dark(), routerConfig: appRouter)));
    Future<void> tap(String key) async {
      await tester.runAsync(() => tester.tap(find.byKey(ValueKey(key)).last));
      await settle(tester);
    }

    for (final entry in {
      'desktopOffline': '/desktop-connection',
      'staleData': '/syncing-usage',
      'costUnavailable': '/model-pricing',
      'partialData': '/tokens',
      'connected': '/waiting-first-usage',
    }.entries) {
      appRouter.go('/ui-state/${entry.key}?period=Week');
      await settle(tester);
      await tap('reviewed-state-action');
      expect(appRouter.routeInformationProvider.value.uri.path, entry.value);
      expect(
          appRouter
              .routeInformationProvider.value.uri.queryParameters['period'],
          'Week');
      if (entry.key == 'staleData') {
        await tap('mock-complete-sync');
        expect(appRouter.routeInformationProvider.value.uri.path, '/tokens');
        expect(
            appRouter
                .routeInformationProvider.value.uri.queryParameters['period'],
            'Week');
      }
    }
    appRouter.go('/ui-state/existingDesktop?period=Week');
    await settle(tester);
    await tap('reviewed-state-action');
    expect(
        tester
            .widget<FigmaPixelScreen>(find.byType(FigmaPixelScreen).last)
            .screenId,
        'M10');
    await tap('figma-hotspot-Back');
    expect(find.byKey(const ValueKey('reviewed-state-action')), findsOneWidget);

    for (final state in ['permissionDenied', 'unsupportedOs']) {
      appRouter.go('/ui-state/$state?period=Week');
      await settle(tester);
      await tap('reviewed-state-action');
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Close'));
      await settle(tester);
      expect(
          find.byKey(const ValueKey('reviewed-state-action')), findsOneWidget);
    }
    appRouter.go('/desktop-connection?period=Week');
    await settle(tester);
    await tap('figma-hotspot-Back');
    expect(appRouter.canPop(), isFalse,
        reason:
            'Direct-entry Back must replace the route, not push a back loop');
    appRouter.go('/tokens?period=Week');
    await settle(tester);
    await tap('figma-hotspot-Refresh');
    expect(
        appRouter.routeInformationProvider.value.uri.queryParameters['period'],
        'Week');
    expect(find.text('Updating latest usage'), findsOneWidget);
    await tap('reviewed-state-action');
    expect(appRouter.routeInformationProvider.value.uri.path, '/tokens');
    expect(
        appRouter.routeInformationProvider.value.uri.queryParameters['period'],
        'Week');
    expect(tester.takeException(), isNull);
  });
}
