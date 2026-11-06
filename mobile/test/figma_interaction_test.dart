import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:utoken_mobile/app/figma_routes.dart';
import 'package:utoken_mobile/core/mock/figma_mock_repository.dart';
import 'package:utoken_mobile/features/figma/presentation/figma_pixel_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('extra demo hotspots are separate from original Figma data', () async {
    final config = await FigmaMockRepository.demoInteractions();
    expect(config['areas'], isA<Map>());
    final spots = await FigmaMockRepository.hotspots('M04');
    expect(spots.any((spot) => spot.name == 'Week'), true);
    expect(spots.any((spot) => spot.name == 'Refresh'), true);
    expect(spots.any((spot) => spot.name == 'Open full report'), true);
  });

  testWidgets('Tokens filters and bottom navigation respond to taps',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/tokens',
      routes: [
        for (final item in figmaRoutes.entries)
          GoRoute(
            path: item.value,
            builder: (context, state) => FigmaPixelScreen(screenId: item.key),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.runAsync(() async {
      await FigmaMockRepository.screen('M04', Brightness.light);
      await FigmaMockRepository.hotspots('M04');
      await FigmaMockRepository.demoInteractions();
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Total tokens'), findsOneWidget);

    await tester.tapAt(const Offset(152, 134));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Đã chọn Week'), findsWidgets);

    await tester.tapAt(const Offset(148, 824));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 110)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Analytics'), findsWidgets);
  });
}
