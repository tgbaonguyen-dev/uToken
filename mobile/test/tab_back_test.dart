import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:utoken_mobile/core/ui/ut_kit.dart';

void main() {
  testWidgets('system back on a tab returns to Tokens', (tester) async {
    Widget tab(int i) =>
        UtTabPage(title: 'tab$i', tabIndex: i, body: const SizedBox.expand());
    final router = GoRouter(initialLocation: '/tokens', routes: [
      for (final (i, path) in [
        (0, '/tokens'),
        (1, '/analytics'),
        (2, '/insights'),
        (3, '/settings')
      ])
        GoRoute(path: path, builder: (_, __) => tab(i)),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/insights');
    await tester.pumpAndSettle();
    expect(find.text('tab2'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('tab0'), findsOneWidget);

    // First back on Tokens only warns.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Press back again to exit'), findsOneWidget);
  });

  testWidgets('tab header and divider line up with or without refresh',
      (tester) async {
    Future<(double, double)> layout(bool refresh) async {
      await tester.pumpWidget(MaterialApp(
          home: UtTabPage(
              title: 'Title',
              subtitle: 'Subtitle',
              tabIndex: refresh ? 0 : 3,
              onRefresh: refresh ? () async {} : null,
              body: const SizedBox.expand())));
      await tester.pump();
      return (
        tester.getTopLeft(find.text('Subtitle')).dy,
        tester.getTopLeft(find.byType(UtDivider).first).dy,
      );
    }

    final withRefresh = await layout(true);
    final settingsLike = await layout(false);
    expect(settingsLike, withRefresh);
  });
}
