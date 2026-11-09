import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/core/mock/figma_mock_repository.dart';
import 'package:utoken_mobile/features/figma/presentation/figma_pixel_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full Analytics totals stay readable and fit their hero slot',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      await FigmaMockRepository.updateSettings({'numberFormat': 'Full'});
      await FigmaMockRepository.hotspots('M05');
      for (final period in ['Day', 'Week', 'Month', 'Total']) {
        final full = await FigmaMockRepository.usageScreen(
            'M05', Brightness.dark,
            period: period);
        final design = await FigmaMockRepository.screen('M05', Brightness.dark);
        expect(full.layers[13]['sz'], design.layers[13]['sz']);
      }
    });
    for (final entry in {
      'Day': '244,000',
      'Week': '2,000,000',
      'Month': '6,830,736',
      'Total': '18,450,000'
    }.entries) {
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData.dark(),
          home: FigmaPixelScreen(screenId: 'M05', initialPeriod: entry.key)));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      final finder = find.text(entry.value);
      expect(finder, findsOneWidget);
      final text = tester.widget<Text>(finder);
      expect(text.maxLines, 1);
      expect(text.style!.fontSize, greaterThan(9));
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      final scale = paragraph.getTransformTo(null).storage[0].abs();
      expect(text.style!.fontSize! * scale, greaterThanOrEqualTo(14));
      expect(tester.getRect(finder).width, lessThanOrEqualTo(150.01));
      expect(tester.takeException(), isNull);
    }
  });

  test(
      'M07 total sums both recommendations and M08 reads the same context amount',
      () async {
    final fixtures = jsonDecode(await rootBundle
        .loadString('lib/core/mock/data/usage_explorer.json')) as Map;
    for (final period in ['Day', 'Week', 'Month', 'Total']) {
      final s = fixtures['periods'][period]['suggestions'] as Map;
      final expected =
          (s['contextSavings'] as num) + (s['cacheSavings'] as num);
      final screen = await FigmaMockRepository.usageScreen(
          'M07', Brightness.dark,
          period: period);
      expect(screen.layers[5]['v'], '\$${expected.toStringAsFixed(2)}');
      expect(screen.layers[17]['v'],
          contains('\$${(s['cacheSavings'] as num).toStringAsFixed(2)}'));
    }
    final context =
        fixtures['periods']['Month']['suggestions']['contextSavings'] as num;
    final insight = await FigmaMockRepository.insightScreen();
    final cost = insight.layers
        .singleWhere((l) => l['bind'] == 'impact_summary.cost')['v'];
    expect(cost, contains('\$${context.toStringAsFixed(2)} / month'));
    final summary =
        await FigmaMockRepository.usageScreen('M07', Brightness.dark);
    expect(summary.layers[5]['v'], r'$13.60');
  });
}
