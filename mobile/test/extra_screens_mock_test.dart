import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:utoken_mobile/app/figma_routes.dart';
import 'package:utoken_mobile/core/mock/figma_mock_repository.dart';
import 'package:utoken_mobile/features/figma/presentation/figma_pixel_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    await FigmaMockRepository.updateSettings({
      'numberFormat': 'Compact',
      'monthlyLimit': 50.0,
      'aiProvider': 'OpenAI',
      'aiModel': 'gpt-5.5-mini',
      'aiKeyPresent': true,
      'aiConnection': 'Connected',
      'aiCheckedAt': 'Not checked'
    });
  });

  test('extra frames bind fixtures without mutating design exports', () async {
    for (final id in FigmaMockRepository.extraScreenIds) {
      final raw = await FigmaMockRepository.screen(id, Brightness.dark);
      final before = jsonEncode(raw.layers);
      final data = await FigmaMockRepository.extraScreen(id, Brightness.dark);
      expect(data.layers, isNotEmpty);
      expect(jsonEncode(raw.layers), before);
    }
  });

  test('export summary matches JSON and CSV records', () async {
    final payload =
        jsonDecode(await FigmaMockRepository.exportPreview('JSON')) as Map;
    final rows = (payload['records'] as List).cast<Map>();
    final csv = (await FigmaMockRepository.exportPreview('CSV')).split('\n');
    expect(payload['sample'], true);
    expect(csv.length, rows.length + 1);
    expect(csv.first.split(','), hasLength(7));
    for (final row in rows) {
      expect(
          (row['gemini_tokens'] as num) +
              (row['codex_tokens'] as num) +
              (row['claude_tokens'] as num),
          row['tokens']);
    }
    final summary =
        await FigmaMockRepository.extraScreen('O01', Brightness.dark);
    expect(summary.layers[8]['v'], startsWith('${rows.length} daily records'));
    expect(summary.layers[14]['v'], rows.length.toString());
    final total = rows.fold<num>(0, (n, r) => n + (r['tokens'] as num));
    expect(summary.layers[10]['v'], '${(total / 1000000).toStringAsFixed(2)}M');
    final cents = rows.fold<int>(
        0, (n, r) => n + ((r['estimated_cost_usd'] as num) * 100).round());
    expect(summary.layers[12]['v'], '\$${(cents / 100).toStringAsFixed(2)}');
    await expectLater(
        FigmaMockRepository.exportPreview('wrong'), throwsArgumentError);
  });

  test('cost example shares catalog rates and budget alert follows saved limit',
      () async {
    final catalog =
        await FigmaMockRepository.extraScreen('M14', Brightness.dark);
    final costs = await FigmaMockRepository.extraScreen('O03', Brightness.dark);
    expect(catalog.layers[16]['v'], r'$0.175');
    expect(costs.layers[7]['v'], r'$0.5985');
    expect(costs.layers[22]['v'], r'$0.5985');
    final sum = [13, 16, 19].fold<double>(
        0,
        (n, i) =>
            n + double.parse((costs.layers[i]['v'] as String).substring(1)));
    expect(sum, closeTo(.5985, .000001));
    final original =
        await FigmaMockRepository.extraScreen('O02', Brightness.dark);
    expect(original.layers[8]['v'], r'$45.02 of $50.00');
    await FigmaMockRepository.updateSettings({'monthlyLimit': 100.0});
    final alert = await FigmaMockRepository.extraScreen('O02', Brightness.dark);
    expect(alert.layers[8]['v'], r'$90.04 of $100.00');
    expect(alert.layers[11]['v'], r'$9.96 remaining');
    expect(alert.layers[10]['w'], lessThanOrEqualTo(318));
  });

  test('AI selections validate models and produce only mock connection results',
      () async {
    await FigmaMockRepository.selectAiProvider('Anthropic');
    await expectLater(
        FigmaMockRepository.updateSettings({'aiModel': 'gpt-5.5-mini'}),
        throwsArgumentError);
    await expectLater(
        FigmaMockRepository.selectAiProvider('wrong'), throwsArgumentError);
    await FigmaMockRepository.testAiConnection();
    expect((await FigmaMockRepository.settingsData())['aiConnection'],
        'Missing key');
    await FigmaMockRepository.updateSettings({'aiKeyPresent': true});
    await FigmaMockRepository.testAiConnection();
    expect((await FigmaMockRepository.settingsData())['aiConnection'],
        'Connected');
    final ai = await FigmaMockRepository.extraScreen('M15', Brightness.dark);
    expect(ai.layers[11]['y'], 266);
    expect(ai.layers[21]['v'], 'claude-sonnet');
    expect(ai.layers[25]['v'], contains('demo-ant-'));
    final settings =
        await FigmaMockRepository.settingsScreen('M09', Brightness.dark);
    expect(settings.layers[57]['v'], 'Anthropic \u00b7 claude-sonnet');
  });

  testWidgets(
      'export preview, alert dismissal and cost/pricing routes are connected',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = _router('/account');
    addTearDown(router.dispose);
    await _warm(tester);
    await tester.pumpWidget(
        MaterialApp.router(theme: ThemeData.dark(), routerConfig: router));
    Future<void> settle() => _settle(tester);
    Future<void> tap(String name) async {
      await tester.runAsync(
          () => tester.tap(find.byKey(ValueKey('figma-hotspot-$name')).first));
      await settle();
    }

    await settle();
    await tap('Export data');
    await tap('Download CSV');
    expect(find.text('CSV preview (mock)'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    await tester.tap(find.text('Close').last);
    await settle();
    await tap('Download JSON');
    expect(find.text('JSON preview (mock)'), findsOneWidget);
    await tester.tap(find.text('Close').last);
    await settle();
    router.go('/budget');
    await settle();
    await tester.tap(find.byKey(const ValueKey('mock-budget-alert-preview')));
    await settle();
    expect(find.text(r'$45.02 of $50.00'), findsOneWidget);
    await tap('Dismiss alert');
    expect(find.text('Budget'), findsOneWidget);
    router.go('/cost-breakdown');
    await settle();
    expect(find.text(r'$0.5985'), findsNWidgets(2));
    await tap('View model pricing');
    expect(find.text('Model pricing'), findsOneWidget);
    await tap('Back');
    expect(find.text('Estimated cost'), findsOneWidget);
    await tap('Close');
    expect(router.routeInformationProvider.value.uri.path, '/tokens');
    expect(find.text('Total tokens'), findsOneWidget);
  });

  testWidgets(
      'AI provider, model, demo key and Test connection update the same session',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = _router('/settings');
    addTearDown(router.dispose);
    await _warm(tester);
    await tester.pumpWidget(
        MaterialApp.router(theme: ThemeData.dark(), routerConfig: router));
    Future<void> settle() => _settle(tester);
    Future<void> tap(String name) async {
      await tester.runAsync(
          () => tester.tap(find.byKey(ValueKey('figma-hotspot-$name')).first));
      await settle();
    }

    await settle();
    await tap('Open AI suggestions');
    expect(
        tester
            .widget<FigmaPixelScreen>(find.byType(FigmaPixelScreen).last)
            .screenId,
        'M15');
    expect(find.text('AI suggestions'), findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .toList()
            .toString());
    await tap('Anthropic');
    expect(find.text('claude-sonnet'), findsOneWidget);
    expect(find.text('No demo key'), findsOneWidget);
    await tap('Edit model');
    await tester.tap(find.text('claude-haiku').last);
    await settle();
    expect(find.text('claude-haiku'), findsOneWidget);
    await tap('Test connection');
    expect(find.text('Missing key'), findsOneWidget);
    await tap('Edit API key');
    await tester.tap(find.text('Use demo key').last);
    await settle();
    await tap('Test connection');
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('AI suggestions'), findsOneWidget);
    await tap('Back');
    expect(find.text('Anthropic \u00b7 claude-haiku'), findsOneWidget);
  });
}

GoRouter _router(String path) => GoRouter(initialLocation: path, routes: [
      for (final entry in figmaRoutes.entries)
        GoRoute(
            path: entry.value,
            builder: (_, state) => FigmaPixelScreen(
                screenId: entry.key,
                initialPeriod: state.uri.queryParameters['period'] ?? 'Month'))
    ]);
Future<void> _warm(WidgetTester tester) => tester.runAsync(() async {
      await FigmaMockRepository.tokensScreen(Brightness.dark);
      for (final id in ['O01', 'O02', 'O03', 'M14', 'M15']) {
        await FigmaMockRepository.extraScreen(id, Brightness.dark);
        await FigmaMockRepository.hotspots(id);
      }
      for (final id in ['M09', 'M11', 'M13']) {
        await FigmaMockRepository.settingsScreen(id, Brightness.dark);
        await FigmaMockRepository.hotspots(id);
      }
    }).then((_) {});
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 2; i++) {
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pumpAndSettle();
  }
}
