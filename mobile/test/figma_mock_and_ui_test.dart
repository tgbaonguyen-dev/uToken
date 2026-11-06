import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/app/figma_routes.dart';
import 'package:utoken_mobile/core/mock/figma_mock_repository.dart';
import 'package:utoken_mobile/features/figma/presentation/figma_pixel_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('20 non-state Figma frames are available in Light and Dark', () async {
    expect(figmaRoutes.length, 20);
    for (final id in figmaRoutes.keys) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final frame = await FigmaMockRepository.screen(id, brightness);
        expect(frame.width, 390, reason: id);
        expect(frame.height, 844, reason: id);
        expect(frame.layers, isNotEmpty, reason: id);
      }
    }
    for (final stateId in ['S01', 'S02', 'S03', 'S04']) {
      expect(figmaRoutes.containsKey(stateId), isFalse);
    }
  });

  testWidgets('Welcome renders literal Figma copy from mock data',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(
      () => FigmaMockRepository.screen('M01', Brightness.light),
    );
    await tester.pumpWidget(
      const MaterialApp(home: FigmaPixelScreen(screenId: 'M01')),
    );
    // AssetBundle decoding is asynchronous outside the fake-async frame loop.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Track your'), findsOneWidget);
    expect(find.text('AI usage.'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('View demo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
