import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/core/mock/figma_mock_repository.dart';
import 'package:utoken_mobile/features/figma/presentation/figma_pixel_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'all M/O Figma screens paint their mock text without Flutter errors',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final id in FigmaMockRepository.screenIds) {
      final data = await tester.runAsync(
        () => FigmaMockRepository.screen(id, Brightness.light),
      );
      expect(data, isNotNull, reason: id);

      await tester.pumpWidget(
        MaterialApp(home: FigmaPixelScreen(screenId: id)),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();

      final sourceText = data!.layers.firstWhere(
        (layer) => layer['t'] == 't',
      )['v'];
      expect(find.text(sourceText, skipOffstage: false), findsWidgets,
          reason: id);
      expect(tester.takeException(), isNull, reason: id);
    }
  });
}
