import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:utoken_mobile/app/figma_routes.dart';
import 'package:utoken_mobile/core/mock/figma_mock_repository.dart';
import 'package:utoken_mobile/features/figma/presentation/figma_pixel_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'all explorer screens bind each period in both themes without changing exports',
      () async {
    for (final brightness in Brightness.values) {
      for (final id in FigmaMockRepository.explorerScreenIds) {
        final original = await FigmaMockRepository.screen(id, brightness);
        final originalText = original.layers.map((l) => l['v']).toList();
        for (final period in ['Day', 'Week', 'Month', 'Total']) {
          final screen = await FigmaMockRepository.usageScreen(id, brightness,
              period: period);
          expect(screen.layers, isNotEmpty, reason: '$id $period $brightness');
          expect(screen.width, original.width);
          for (final layer in screen.layers) {
            expect((layer['w'] as num).isFinite, true);
            expect((layer['h'] as num).isFinite, true);
          }
        }
        expect(original.layers.map((l) => l['v']), originalText);
      }
    }
  });

  test('analytics and details agree on ranked models and period totals',
      () async {
    for (final period in ['Day', 'Week', 'Month', 'Total']) {
      final analytics = await FigmaMockRepository.usageScreen(
          'M05', Brightness.dark,
          period: period);
      final details = await FigmaMockRepository.usageScreen(
          'M04B', Brightness.dark,
          period: period);
      final tokens = await FigmaMockRepository.tokensScreen(Brightness.dark,
          period: period);
      expect(analytics.layers[14]['v'],
          (tokens.layers[14]['v'] as String).replaceAll(' estimated', ''));
      for (var i = 0; i < 4; i++) {
        expect(analytics.layers[[24, 28, 32, 36][i]]['v'],
            details.layers[[7, 12, 17, 22][i]]['v']);
        expect(analytics.layers[[25, 29, 33, 37][i]]['v'],
            details.layers[[8, 13, 18, 23][i]]['v']);
      }
    }
  });

  test('comparison changes winners and descending rankings for each task size',
      () async {
    final expected = {
      'Small': 'gemini-2.5-flash',
      'Medium': 'gemini-2.5-pro',
      'Large': 'gpt-5.5-codex'
    };
    for (final brightness in Brightness.values) {
      for (final entry in expected.entries) {
        final screen = await FigmaMockRepository.usageScreen('M05C', brightness,
            taskSize: entry.key);
        expect(screen.layers[15]['v'], entry.value);
        expect(screen.layers[28]['v'], entry.value);
        final ranking = [31, 40, 49]
            .map((i) => double.parse(screen.layers[i]['v'] as String))
            .toList();
        expect(ranking[0], greaterThan(ranking[1]));
        expect(ranking[1], greaterThan(ranking[2]));
        expect(screen.layers[14]['c'], screen.layers[27]['c']);
      }
    }
  });

  test(
      'daily grouping preserves totals and sorts numerically in both directions',
      () async {
    for (final grouping in ['Daily', 'Project']) {
      for (final key in ['tokens', 'chats']) {
        final desc = await FigmaMockRepository.usageScreen(
            'M06', Brightness.dark,
            grouping: grouping, sortBy: key);
        final asc = await FigmaMockRepository.usageScreen(
            'M06', Brightness.dark,
            grouping: grouping, sortBy: key, ascending: true);
        final column = key == 'tokens' ? 14 : 15;
        final down = [
          for (var i = 0; i < 8; i++) desc.layers[column + 4 * i]['v']
        ];
        final up = [
          for (var i = 0; i < 8; i++) asc.layers[column + 4 * i]['v']
        ];
        expect(down.reversed, up);
        expect(desc.layers[13]['v'], grouping == 'Daily' ? '28 Oct' : 'uToken');
      }
    }
    final daily =
        await FigmaMockRepository.usageScreen('M06', Brightness.light);
    final projects = await FigmaMockRepository.usageScreen(
        'M06', Brightness.light,
        grouping: 'Project');
    num sum(FigmaMockScreen screen, int col) => [
          for (var i = 0; i < 8; i++)
            double.parse(
                (screen.layers[col + 4 * i]['v'] as String).replaceAll('K', ''))
        ].reduce((a, b) => a + b);
    expect(sum(daily, 14), closeTo(sum(projects, 14), 0.001));
    expect(sum(daily, 15), sum(projects, 15));
    await expectLater(
        FigmaMockRepository.usageScreen('M06', Brightness.dark,
            sortBy: 'wrong'),
        throwsArgumentError);
  });

  testWidgets('filters change mock data and drill-down keeps the chosen period',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(initialLocation: '/analytics', routes: [
      for (final route in figmaRoutes.entries)
        GoRoute(
            path: route.value,
            builder: (_, state) => FigmaPixelScreen(
                screenId: route.key,
                initialPeriod: state.uri.queryParameters['period'] ?? 'Month')),
    ]);
    addTearDown(router.dispose);
    Future<void> settle() async {
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
    }

    Future<void> tap(String name) async {
      await tester.tap(find.byKey(ValueKey('figma-hotspot-$name')).first);
      await settle();
    }

    await tester.pumpWidget(
        MaterialApp.router(theme: ThemeData.dark(), routerConfig: router));
    await settle();
    expect(find.text('6.83M'), findsOneWidget);
    await tap('Day');
    expect(find.text('244.0K'), findsOneWidget);
    await tap('Week');
    expect(find.text('2.00M'), findsOneWidget);
    await tap('Total');
    expect(find.text('18.45M'), findsOneWidget);
    await tap('Day');
    await tap('Open efficiency');
    expect(
        tester
            .widget<FigmaPixelScreen>(find.byType(FigmaPixelScreen).last)
            .initialPeriod,
        'Day');
    expect(find.text('Results per token \u00b7 today'), findsOneWidget);
    await tap('Compare models');
    await tap('Small');
    expect(find.text('BEST FOR SMALL TASKS'), findsOneWidget);
    expect(find.text('gemini-2.5-flash'), findsNWidgets(2));
    await tap('Large');
    expect(find.text('BEST FOR LARGE TASKS'), findsOneWidget);
    expect(find.text('gpt-5.5-codex'), findsNWidgets(2));
    await tap('Medium');
    expect(find.text('BEST FOR MEDIUM TASKS'), findsOneWidget);
    router.go('/tokens?period=Week');
    await settle();
    await tap('Open full report');
    expect(find.text('Top models / Week'), findsOneWidget);
    await tap('See all days');
    expect(find.text('Daily usage'), findsOneWidget);
    await tap('Project');
    expect(find.text('Project usage'), findsOneWidget);
    expect(find.text('Camellia'), findsOneWidget);
    await tap('Sort tokens');
    expect(find.text('Total ↓'), findsOneWidget);
    await tap('Sort tokens');
    expect(find.text('Total ↑'), findsOneWidget);
    await tap('Daily');
    expect(find.text('Daily usage'), findsOneWidget);
    expect(find.text('01 Nov'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
}
