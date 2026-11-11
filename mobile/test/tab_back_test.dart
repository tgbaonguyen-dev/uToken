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
}
