import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/app/router.dart';
import 'package:utoken_mobile/app/figma_routes.dart';
import 'package:utoken_mobile/core/mock/figma_mock_repository.dart';
import 'package:utoken_mobile/core/widgets/budget_limit_dialog.dart';
import 'package:utoken_mobile/core/widgets/figma_viewport.dart';
import 'package:utoken_mobile/core/widgets/ui_preview_scope.dart';
import 'package:utoken_mobile/features/auth/data/auth_mock_repository.dart';
import 'package:utoken_mobile/features/auth/domain/signing_in_state_model.dart';
import 'package:utoken_mobile/features/auth/presentation/reviewed_state_navigation.dart';

import 'account_states_test.dart' show settle;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('budget accepts only finite amounts in range with two decimals', () {
    for (final value in [
      '',
      '0',
      '-1',
      '100001',
      '1.234',
      'NaN',
      'Infinity',
      '1e3'
    ]) {
      expect(BudgetLimitDialog.validate(value), isNotNull, reason: value);
    }
    for (final value in ['1', '100000', ' 50.25 ']) {
      expect(BudgetLimitDialog.validate(value), isNull, reason: value);
    }
  });

  test('every progress preview has valid deterministic outcomes', () async {
    final outcomes =
        (await FigmaMockRepository.extraData())['statePreviewOutcomes'] as Map;
    expect(outcomes.keys.toSet(), demoProgressStates);
    for (final options in outcomes.values) {
      expect(options, isNotEmpty);
      for (final option in options) {
        final path = option['path'] as String;
        expect(
            figmaRoutes.containsValue(path) ||
                AuthScreenState.values
                    .any((state) => path == '/ui-state/${state.name}'),
            isTrue,
            reason: path);
      }
    }
  });

  testWidgets(
      'short viewport scrolls without shrinking canvas and respects safe area',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(390, 568),
                padding: EdgeInsets.only(top: 24, bottom: 20)),
            child: Scaffold(
                body: FigmaViewport(
                    width: 390,
                    height: 844,
                    builder: (_) => SizedBox(
                        key: const ValueKey('canvas'),
                        child: Align(
                            alignment: Alignment.bottomCenter,
                            child: TextButton(
                                onPressed: () {},
                                child: const Text('Bottom action')))))))));
    expect(tester.getSize(find.byKey(const ValueKey('canvas'))),
        const Size(390, 844));
    expect(tester.getTopLeft(find.byKey(const ValueKey('canvas'))).dy, 24);
    await tester.ensureVisible(find.text('Bottom action'));
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(find.text('Bottom action')).dy,
        lessThanOrEqualTo(548));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'large text enlarges the reference canvas without overlapping text layers',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(390, 568), textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
                body: FigmaViewport(
                    width: 390,
                    height: 844,
                    builder: (_) => Builder(builder: (context) {
                          expect(
                              MediaQuery.textScalerOf(context).scale(16), 16);
                          return const SizedBox(key: ValueKey('large-canvas'));
                        }))))));
    expect(tester.getSize(find.byKey(const ValueKey('large-canvas'))),
        const Size(585, 1266));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'budget validation, keyboard and large text remain usable on small screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 568),
                viewInsets: EdgeInsets.only(bottom: 180),
                textScaler: TextScaler.linear(1.5)),
            child: child!),
        home: const Scaffold(body: BudgetLimitDialog(initialAmount: 50))));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('mock-budget-input')), '0');
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter 1'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'))
            .onPressed,
        isNull);
    await tester.enterText(
        find.byKey(const ValueKey('mock-budget-input')), '65.25');
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'))
            .onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'preview results, repeated taps, native Back and handoff scope work',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(appRouter.dispose);
    final preview = ValueNotifier(true);
    addTearDown(preview.dispose);
    await tester.runAsync(() async {
      for (final id in ['M01', 'M02', 'M09', 'M11', 'M15']) {
        await FigmaMockRepository.screen(id, Brightness.dark);
        await FigmaMockRepository.hotspots(id);
      }
      await FigmaMockRepository.settingsScreen('M11', Brightness.dark);
      await FigmaMockRepository.extraScreen('M15', Brightness.dark);
      for (final state in [
        AuthScreenState.signingIn,
        AuthScreenState.failed,
        AuthScreenState.initialLoading
      ]) {
        await const AuthMockRepository().getStateData(state);
      }
    });
    await tester.pumpWidget(ProviderScope(
        child: ValueListenableBuilder<bool>(
            valueListenable: preview,
            builder: (_, enabled, __) => UiPreviewScope(
                enabled: enabled,
                child: MaterialApp.router(
                    theme: ThemeData.dark(), routerConfig: appRouter)))));
    await tester.binding.setSurfaceSize(const Size(390, 568));
    appRouter.go('/ui-state/initialLoading');
    await settle(tester);
    final dock =
        tester.getRect(find.byKey(const ValueKey('reviewed-state-tab-0')));
    expect(dock.bottom, 568);
    expect(dock.height, greaterThanOrEqualTo(48));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    appRouter.go('/ui-state/signingIn?period=Week');
    await settle(tester);
    await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('mock-state-outcome'))));
    await settle(tester);
    await tester.runAsync(() => tester.tap(find.text('Sign-in fails')));
    await settle(tester);
    expect(find.text('Retry sign-in'), findsOneWidget);
    expect(
        appRouter.routeInformationProvider.value.uri.queryParameters['period'],
        'Week');
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(appRouter.routeInformationProvider.value.uri.path, '/welcome');
    appRouter.go('/ai-suggestions');
    await settle(tester);
    final edit = find.byKey(const ValueKey('figma-hotspot-Edit API key'));
    expect(find.bySemanticsLabel('Edit API key'), findsWidgets);
    final tap = tester.widget<InkWell>(edit).onTap!;
    await tester.runAsync(() async {
      tap();
      tap();
    });
    await settle(tester);
    expect(find.text('Demo key'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Demo key'), findsNothing);
    preview.value = false;
    await settle(tester);
    expect(find.byKey(const ValueKey('figma-screen-gallery-trigger')),
        findsNothing);
    appRouter.go('/ui-state/signingIn');
    await settle(tester);
    expect(find.byKey(const ValueKey('mock-state-outcome')), findsNothing);
    appRouter.go('/state-preview');
    await settle(tester);
    expect(appRouter.routeInformationProvider.value.uri.path, '/welcome');
    appRouter.go('/budget');
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(appRouter.routeInformationProvider.value.uri.path, '/settings');
    expect(tester.takeException(), isNull);
  });
}
