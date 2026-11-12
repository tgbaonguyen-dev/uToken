import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/app/router.dart';
import 'package:utoken_mobile/app/figma_routes.dart';
import 'package:utoken_mobile/core/mock/figma_mock_repository.dart';
import 'package:utoken_mobile/core/widgets/ui_preview_scope.dart';
import 'package:utoken_mobile/features/auth/domain/mobile_auth.dart';
import 'package:utoken_mobile/features/auth/presentation/reviewed_state_navigation.dart';
import 'package:utoken_mobile/features/figma/presentation/figma_pixel_screen.dart';

import 'mobile_auth_test.dart' show FakeAuthGateway;
import 'account_states_test.dart' show settle;

void main() {
  testWidgets(
      'all preview states and detail Back routes avoid post-login setup loops',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final details = {
      'M04B': ('Back', 'M04'),
      'M05B': ('Back', 'M05'),
      'M05C': ('Back', 'M05B'),
      'M06': ('Back', 'M04B'),
      'M08': ('Back', 'M07'),
      'M10': ('Back', 'M09'),
      'M11': ('Back', 'M09'),
      'M12': ('Back', 'M09'),
      'M13': ('Back', 'M09'),
      'M14': ('Back', 'M09'),
      'M15': ('Back', 'M09'),
      'O01': ('Back', 'M13'),
      'O02': ('Back', 'M11'),
      'O03': ('Dismiss', 'M04'),
    };
    await tester.runAsync(() async {
      for (final id in [...FigmaMockRepository.screenIds, 'M08']) {
        await FigmaMockRepository.screen(id, Brightness.dark);
        await FigmaMockRepository.hotspots(id);
        if (FigmaMockRepository.explorerScreenIds.contains(id)) {
          await FigmaMockRepository.usageScreen(id, Brightness.dark);
        } else if (FigmaMockRepository.extraScreenIds.contains(id)) {
          await FigmaMockRepository.extraScreen(id, Brightness.dark);
        } else if (['M09', 'M10', 'M11', 'M12', 'M13'].contains(id)) {
          await FigmaMockRepository.settingsScreen(id, Brightness.dark);
        }
      }
      await FigmaMockRepository.tokensScreen(Brightness.dark);
      await FigmaMockRepository.insightScreen();
      await FigmaMockRepository.demoInteractions();
    });
    final gateway = FakeAuthGateway();
    final auth = MobileAuthController(gateway);
    gateway.sessions.add(null);
    await auth.signIn();
    expect(auth.signedInDestination, '/tokens');
    final router = createAppRouter(auth: auth);
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    addTearDown(gateway.sessions.close);
    await tester.pumpWidget(ProviderScope(
        child: MobileAuthScope(
            controller: auth,
            child: UiPreviewScope(
                enabled: false,
                child: MaterialApp.router(
                    theme: ThemeData.dark(), routerConfig: router)))));
    await settle(tester);
    final states = reviewedStates.values.expand((states) => states).toList();
    expect(states, hasLength(74));
    for (final path in [
      ...states.map((s) => '/ui-state/${s.name}'),
      '/state-preview',
      '/auth/signing-in'
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/tokens',
          reason: path);
    }
    await settle(tester);
    for (final entry in details.entries) {
      router.go(figmaPathFor(entry.key)!);
      await settle(tester);
      await tester.runAsync(() => tester
          .tap(find.byKey(ValueKey('figma-hotspot-${entry.value.$1}')).last));
      await settle(tester);
      expect(
          tester
              .widget<FigmaPixelScreen>(find.byType(FigmaPixelScreen).last)
              .screenId,
          entry.value.$2,
          reason: '${entry.key} / ${entry.value.$1}');
      expect(router.canPop(), isFalse,
          reason: '${entry.key} must not push its fallback');
    }
    expect(tester.takeException(), isNull);
  });
}
