import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/app/router.dart';
import 'package:utoken_mobile/features/auth/domain/mobile_auth.dart';
import 'mobile_auth_test.dart' show FakeAuthGateway, signedInUser;
import 'account_states_test.dart' show settle;

void main() {
  test('demo never calls the authentication gateway', () async {
    final gateway = FakeAuthGateway();
    final auth = MobileAuthController(gateway);
    gateway.sessions.add(null);
    auth.enterDemo();
    expect(auth.demoMode, isTrue);
    expect(gateway.signInCalls, 0);
    expect(gateway.signOutCalls, 0);
    auth.exitDemo();
    expect(auth.demoMode, isFalse);
    auth.dispose();
    await gateway.sessions.close();
  });
  test('expired session clears the user and exposes sign-in recovery',
      () async {
    final gateway = FakeAuthGateway();
    final auth = MobileAuthController(gateway);
    gateway.sessions.add(signedInUser);
    await auth.expireSession();
    expect(auth.user, isNull);
    expect(auth.message, contains('Session expired'));
    expect(auth.demoMode, isFalse);
    expect(auth.busy, isFalse);
    auth.dispose();
    await gateway.sessions.close();
  });
  testWidgets('Welcome has no demo bypass and guards signed-out routes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = FakeAuthGateway();
    final auth = MobileAuthController(gateway);
    gateway.sessions.add(null);
    final router = createAppRouter(auth: auth);
    await tester.pumpWidget(MobileAuthScope(
        controller: auth,
        child:
            MaterialApp.router(theme: ThemeData.dark(), routerConfig: router)));
    await settle(tester);
    expect(find.text('View demo'), findsNothing);
    expect(find.text('Continue with Google'), findsOneWidget);
    for (final path in [
      '/tokens',
      '/settings',
      '/connect-desktop',
      '/state-preview'
    ]) {
      router.go(path);
      await settle(tester);
      expect(router.routeInformationProvider.value.uri.path, '/welcome');
    }
    expect(gateway.signInCalls, 0);
    expect(auth.demoMode, isFalse);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    auth.dispose();
    await gateway.sessions.close();
  });
}
