import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:utoken_mobile/app/figma_routes.dart';
import 'package:utoken_mobile/core/mock/figma_mock_repository.dart';
import 'package:utoken_mobile/features/figma/presentation/figma_pixel_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bottom nav remains clickable in wide LDPlayer landscape', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 800));
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
      for (final id in ['M04', 'M05', 'M07', 'M09']) {
        await FigmaMockRepository.screen(id, Brightness.light);
      }
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pumpAndSettle();

    for (final (index, path) in [
      (1, '/analytics'),
      (2, '/insights'),
      (3, '/settings'),
      (0, '/tokens'),
    ]) {
      final target = find.byKey(ValueKey('utoken-tab-$index'));
      expect(target, findsOneWidget);
      final bounds = tester.getRect(target);
      expect(bounds.height, greaterThan(45));
      expect(bounds.left, greaterThan(400));
      expect(bounds.right, lessThan(1050));
      await tester.tap(target);
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 70)));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, path);
      expect(tester.takeException(), isNull);
    }
  });
}
