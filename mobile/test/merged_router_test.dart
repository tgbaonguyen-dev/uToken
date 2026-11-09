import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/app/router.dart';
import 'package:utoken_mobile/core/mock/figma_mock_repository.dart';
import 'package:utoken_mobile/features/auth/presentation/signing_in_screen.dart';
import 'package:utoken_mobile/features/insights/presentation/insight_detail_screen.dart';
import 'package:utoken_mobile/main_preview.dart';

void main() {
  testWidgets(
      'merged router connects Figma insights to hand-built detail and states',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(appRouter.dispose);
    await tester.runAsync(() async {
      await FigmaMockRepository.screen('M07', Brightness.light);
      await FigmaMockRepository.hotspots('M07');
      await FigmaMockRepository.demoInteractions();
    });
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(routerConfig: appRouter),
    ));
    appRouter.go('/insights');
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    expect(find.text('Small changes based on your usage.'), findsOneWidget);
    await tester
        .tap(find.byKey(const ValueKey('figma-hotspot-Trim repeated context')));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.byType(InsightDetailScreen), findsOneWidget);

    appRouter.go('/ui-state/failed');
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.text('Retry sign-in'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reviewed-state-action')));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.text('Signing you in'), findsOneWidget);

    appRouter.go('/ui-state/initialLoading');
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.text('Loading your usage'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reviewed-state-tab-1')));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/analytics');

    appRouter.go('/ui-state/connected');
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.text('Desktop connected'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reviewed-state-action')));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path,
        '/waiting-first-usage');

    appRouter.go('/state-preview');
    await tester.pumpAndSettle();
    expect(find.byType(PreviewApp), findsOneWidget);
    expect(find.byType(SigningInScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
