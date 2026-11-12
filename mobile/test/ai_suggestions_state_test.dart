import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/app/router.dart';
import 'package:utoken_mobile/core/mock/figma_mock_repository.dart';
import 'package:utoken_mobile/features/auth/data/auth_mock_repository.dart';
import 'package:utoken_mobile/features/auth/domain/signing_in_state_model.dart';
import 'package:utoken_mobile/features/auth/presentation/reviewed_state_navigation.dart';
import 'package:utoken_mobile/features/figma/presentation/figma_pixel_screen.dart';

import 'account_states_test.dart' show settle;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all 74 named states have distinct source layouts and selectors',
      () async {
    final nodes = <String>{};
    for (final entry in reviewedStates.entries) {
      for (final state in entry.value) {
        final data = await const AuthMockRepository().getStateData(state);
        expect(data.screenId, entry.key);
        expect(nodes.add(data.figmaLayout!['node']), isTrue);
      }
    }
    expect(nodes.length, 74);
    final data = await const AuthMockRepository()
        .getStateData(AuthScreenState.aiSuggestionsInvalidApiKey);
    expect(data.figmaLayout!['node'], '153:3383');
    expect(data.figmaLayout!['button_top'], 700);
    expect(data.card.items.first.subtitle, 'OpenAI · gpt-5.5-mini');
  });

  testWidgets(
      'invalid key recovery opens existing demo editor without clearing data',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(appRouter.dispose);
    late String before;
    await tester.runAsync(() async {
      await const AuthMockRepository()
          .getStateData(AuthScreenState.aiSuggestionsInvalidApiKey);
      await FigmaMockRepository.extraScreen('M15', Brightness.dark);
      await FigmaMockRepository.hotspots('M15');
      before = await FigmaMockRepository.exportPreview('JSON');
    });
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp.router(
            theme: ThemeData.dark(), routerConfig: appRouter)));
    appRouter.go('/ui-state/aiSuggestionsInvalidApiKey');
    await settle(tester);
    expect(find.text('The provider rejected this key'), findsOneWidget);
    expect(tester.getRect(find.byKey(const ValueKey('reviewed-state-action'))),
        const Rect.fromLTWH(20, 700, 350, 52));
    await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('reviewed-state-action'))));
    await settle(tester);
    expect(
        tester
            .widget<FigmaPixelScreen>(find.byType(FigmaPixelScreen).last)
            .screenId,
        'M15');
    await tester.runAsync(() => tester
        .tap(find.byKey(const ValueKey('figma-hotspot-Edit API key')).last));
    await settle(tester);
    expect(find.text('Demo key'), findsOneWidget);
    expect(find.text('Use demo key'), findsOneWidget);
    await tester.runAsync(() => tester.tap(find.text('Use demo key')));
    await settle(tester);
    await tester.runAsync(() =>
        tester.tap(find.byKey(const ValueKey('figma-hotspot-Back')).last));
    await settle(tester);
    expect(find.text('The provider rejected this key'), findsOneWidget);
    expect(
        await tester.runAsync(() => FigmaMockRepository.exportPreview('JSON')),
        before);
    expect(tester.takeException(), isNull);
  });
}
