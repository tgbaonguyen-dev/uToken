import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:utoken_mobile/app/figma_routes.dart';
import 'package:utoken_mobile/core/mock/figma_mock_repository.dart';
import 'package:utoken_mobile/features/figma/presentation/figma_pixel_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final defaults = {
    'language': 'System',
    'numberFormat': 'Compact',
    'syncInterval': '15 minutes',
    'monthlyLimit': 50.0,
    'alert90': true,
    'alert100': true,
    'backgroundSync': true,
    'diagnostics': true,
    'connected': true
  };
  setUp(() async => FigmaMockRepository.updateSettings(defaults));

  test('all settings screens load in both themes and share mock preferences',
      () async {
    await FigmaMockRepository.updateSettings({
      'monthlyLimit': 100.0,
      'diagnostics': false,
      'connected': false,
      'language': 'Vietnamese',
      'syncInterval': 'Manual'
    });
    for (final brightness in Brightness.values) {
      for (final id in ['M09', 'M10', 'M11', 'M12', 'M13']) {
        final raw = await FigmaMockRepository.screen(id, brightness);
        final originalText = raw.layers.map((l) => l['v']).toList();
        final screen = await FigmaMockRepository.settingsScreen(id, brightness);
        expect(screen.layers, isNotEmpty);
        expect(raw.layers.map((l) => l['v']), originalText);
      }
      final settings =
          await FigmaMockRepository.settingsScreen('M09', brightness);
      expect(settings.layers[14]['v'], r'$100.00 monthly');
      expect(settings.layers[10]['v'], 'Vietnamese');
      expect(settings.layers[23]['v'], 'Manual');
      expect(settings.layers[6]['v'], 'Not connected');
      final account =
          await FigmaMockRepository.settingsScreen('M13', brightness);
      expect(account.layers[20]['v'], '0 computers');
      expect(account.layers[8]['v'], settings.layers[31]['v']);
      expect(account.layers[13]['v'], 'Paused');
      final privacy =
          await FigmaMockRepository.settingsScreen('M12', brightness);
      expect(privacy.layers[30]['v'], 'Off');
    }
  });

  test('budget draft is isolated until save and progress is capped', () async {
    final draft = await FigmaMockRepository.settingsScreen(
        'M11', Brightness.dark,
        budgetDraft: {'monthlyLimit': 1.0, 'alert90': false});
    expect(draft.layers[9]['w'], 318);
    expect(draft.layers[10]['v'], '4218.0% used');
    expect(draft.layers[20]['v'], 'Off');
    expect((await FigmaMockRepository.settingsData())['monthlyLimit'], 50.0);
    for (final invalid in [0, -1, 100001, double.nan, double.infinity, '50']) {
      await expectLater(
          FigmaMockRepository.updateSettings({'monthlyLimit': invalid}),
          throwsArgumentError);
    }
    await expectLater(
        FigmaMockRepository.updateSettings(
            {'language': 'Vietnamese', 'diagnostics': 'yes'}),
        throwsArgumentError);
    expect((await FigmaMockRepository.settingsData())['language'], 'System');
    await expectLater(
        FigmaMockRepository.updateSettings({'numberFormat': 'Unknown'}),
        throwsArgumentError);
  });

  test('Full token format uses exact fixture numbers across usage and desktop',
      () async {
    await FigmaMockRepository.updateSettings({'numberFormat': 'Full'});
    final tokens = await FigmaMockRepository.tokensScreen(Brightness.dark);
    expect(tokens.layers[19]['v'], '2,000,000');
    final analytics =
        await FigmaMockRepository.usageScreen('M05', Brightness.dark);
    expect(analytics.layers[13]['v'], '6,830,736');
    final desktop =
        await FigmaMockRepository.settingsScreen('M10', Brightness.dark);
    expect(desktop.layers[14]['v'], '4,262,379');
  });

  testWidgets(
      'settings choices, budget save/discard and connection/privacy mocks respond',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(initialLocation: '/settings', routes: [
      for (final item in figmaRoutes.entries)
        GoRoute(
            path: item.value,
            builder: (_, __) => FigmaPixelScreen(screenId: item.key))
    ]);
    addTearDown(router.dispose);
    Future<void> settle() async {
      for (var i = 0; i < 2; i++) {
        await tester.pump();
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pumpAndSettle();
      }
    }

    Future<void> tap(String name) async {
      await tester.tap(find.byKey(ValueKey('figma-hotspot-$name')).first);
      await settle();
    }

    Future<void> choose(String text) async {
      await tester.pump();
      await tester.tap(find.text(text).last);
      await settle();
    }

    await tester.runAsync(() async {
      for (final id in ['M09', 'M10', 'M11', 'M12', 'M13']) {
        await FigmaMockRepository.settingsScreen(id, Brightness.dark);
        await FigmaMockRepository.hotspots(id);
      }
    });
    await tester.pumpWidget(
        MaterialApp.router(theme: ThemeData.dark(), routerConfig: router));
    await settle();
    await tap('Language');
    await choose('Vietnamese');
    expect(find.text('Vietnamese'), findsOneWidget);
    await tap('Sync interval');
    await choose('Manual');
    expect(find.text('Manual'), findsOneWidget);
    await tap('Open budget');
    expect(find.text('Budget'), findsOneWidget,
        reason:
            'Text: ${tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).toList()}');
    await tap('90% alert');
    expect(
        (await tester
            .runAsync(() => FigmaMockRepository.settingsData()))!['alert90'],
        true);
    await tap('Edit monthly limit');
    await tester.enterText(
        find.byKey(const ValueKey('mock-budget-input')), '0');
    await choose('Apply');
    expect(find.textContaining('Enter 1'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('mock-budget-input')), '100');
    await choose('Apply');
    expect(find.text(r'of $100.00'), findsOneWidget);
    await tap('Save budget');
    expect(find.text(r'$100.00 monthly'), findsOneWidget);
    await tap('Open budget');
    await tap('Edit monthly limit');
    await tester.enterText(
        find.byKey(const ValueKey('mock-budget-input')), '200');
    await choose('Apply');
    await tap('Back');
    expect(find.text(r'$100.00 monthly'), findsOneWidget);
    await tap('Open privacy');
    await tap('Diagnostics');
    expect(find.text('Off'), findsOneWidget);
    await tap('Delete data');
    await choose('Cancel');
    expect(find.text('Privacy'), findsOneWidget);
    await tap('Back');
    await tap('Open desktop collector');
    await tap('Background sync');
    expect(
        (await tester.runAsync(
            () => FigmaMockRepository.settingsData()))!['backgroundSync'],
        false);
    await tap('Disconnect this computer');
    await choose('Cancel');
    expect(find.text('Connected'), findsOneWidget);
    await tap('Disconnect this computer');
    await choose('Confirm demo');
    expect(find.text('Disconnected'), findsOneWidget);
    await tap('Sync now');
    expect(find.text('Reconnect the demo computer first.'), findsOneWidget);
    await tap('Back');
    await tap('Open account');
    expect(find.text('0 computers'), findsOneWidget);
    await tap('Google account');
    expect(find.textContaining('camellya@example.com'), findsWidgets);
    await choose('Close');
    await tap('Delete account');
    await choose('Confirm demo');
    expect(find.text('Demo request completed. No data was removed.'),
        findsOneWidget);
  });
}
