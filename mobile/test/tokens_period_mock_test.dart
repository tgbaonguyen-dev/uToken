import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/core/mock/figma_mock_repository.dart';
import 'package:utoken_mobile/features/figma/presentation/figma_pixel_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'period fixtures update metrics, sources and charts without mutating exports',
      () async {
    for (final brightness in Brightness.values) {
      final totals = <String>{};
      for (final period in ['Day', 'Week', 'Month', 'Total']) {
        final screen =
            await FigmaMockRepository.tokensScreen(brightness, period: period);
        totals.add(screen.layers[13]['v'] as String);
        expect(
            screen.layers[8]['x'],
            screen.layers[{
              'Day': 6,
              'Week': 7,
              'Month': 9,
              'Total': 10
            }[period]!]['x']);
        expect(screen.layers[14]['v'], contains('estimated'));
        expect(screen.layers[33]['v'], endsWith('%'));
        expect(
            screen.layers.where((l) =>
                l['v'] ==
                {
                  'Day': 'Today',
                  'Week': 'Last 7 days',
                  'Month': 'Nov 2026',
                  'Total': 'All time'
                }[period]),
            hasLength(1));
      }
      expect(totals, hasLength(4));
      expect(
          (await FigmaMockRepository.screen('M04', brightness)).layers[13]['v'],
          '6,830,736');
    }
    await expectLater(
        FigmaMockRepository.tokensScreen(Brightness.dark, period: 'invalid'),
        throwsArgumentError);
  });

  testWidgets('period taps change displayed mock data and can return to Month',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      for (final period in ['Day', 'Week', 'Month', 'Total']) {
        await FigmaMockRepository.tokensScreen(Brightness.dark, period: period);
      }
      await FigmaMockRepository.hotspots('M04');
    });
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: const FigmaPixelScreen(screenId: 'M04')));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.text('6,830,736'), findsOneWidget);
    for (final entry in {
      'Day': '244,000',
      'Week': '2,000,000',
      'Total': '18,450,000',
      'Month': '6,830,736'
    }.entries) {
      await tester
          .tap(find.byKey(ValueKey('figma-hotspot-${entry.key}')).first);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    }
  });
}
