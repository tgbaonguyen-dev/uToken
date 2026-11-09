import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/app/router.dart';
import 'package:utoken_mobile/core/mock/figma_mock_repository.dart';
import 'package:utoken_mobile/core/widgets/ui_preview_scope.dart';
import 'package:utoken_mobile/features/auth/domain/mobile_auth.dart';
import 'package:utoken_mobile/features/figma/presentation/figma_pixel_screen.dart';

import 'account_states_test.dart' show settle;

const signedInUser = MobileAuthUser(
    uid: 'test-user',
    name: 'Test Google User',
    email: 'test-user@example.test');

class FakeAuthGateway implements MobileAuthGateway {
  final sessions = StreamController<MobileAuthUser?>.broadcast(sync: true);
  int signInCalls = 0;
  int signOutCalls = 0;
  Future<MobileAuthUser?> Function()? signInHandler;
  Future<void> Function()? signOutHandler;

  @override
  Stream<MobileAuthUser?> get sessionChanges => sessions.stream;

  @override
  Future<MobileAuthUser?> signInWithGoogle() async {
    signInCalls++;
    return signInHandler == null ? signedInUser : await signInHandler!();
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutHandler != null) await signOutHandler!();
    sessions.add(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restored session comes from SDK events, sign-out clears it', () async {
    final gateway = FakeAuthGateway();
    final auth = MobileAuthController(gateway);
    addTearDown(auth.dispose);
    addTearDown(gateway.sessions.close);
    expect(auth.ready, isFalse);
    gateway.sessions.add(signedInUser);
    expect(auth.ready, isTrue);
    expect(auth.user?.uid, signedInUser.uid);
    expect(auth.signedInDestination, '/tokens');
    await auth.signOut();
    expect(auth.user, isNull);
    expect(gateway.signOutCalls, 1);
  });

  test('interactive login is single-flight and sets onboarding destination',
      () async {
    final gateway = FakeAuthGateway();
    final result = Completer<MobileAuthUser?>();
    gateway.signInHandler = () => result.future;
    final auth = MobileAuthController(gateway);
    addTearDown(auth.dispose);
    addTearDown(gateway.sessions.close);
    gateway.sessions.add(null);
    final operation = auth.signIn();
    await auth.signIn();
    expect(gateway.signInCalls, 1);
    expect(auth.busy, isTrue);
    result.complete(signedInUser);
    await operation;
    expect(auth.user?.email, signedInUser.email);
    expect(auth.signedInDestination, '/connect-desktop');
    expect(auth.busy, isFalse);
  });

  test('cancel, safe error, retry and sign-out failure retain correct session',
      () async {
    final gateway = FakeAuthGateway();
    final auth = MobileAuthController(gateway);
    addTearDown(auth.dispose);
    addTearDown(gateway.sessions.close);
    gateway.sessions.add(null);
    gateway.signInHandler = () async => null;
    await auth.signIn();
    expect(auth.user, isNull);
    expect(auth.message, contains('cancelled'));
    gateway.signInHandler =
        () async => throw const MobileAuthFailure('No connection. Try again.');
    await auth.signIn();
    expect(auth.message, 'No connection. Try again.');
    gateway.signInHandler =
        () async => throw Exception('sensitive-provider-detail');
    await auth.signIn();
    expect(auth.message, isNot(contains('sensitive-provider-detail')));
    gateway.signInHandler = null;
    await auth.signIn();
    expect(auth.message, isNull);
    gateway.signOutHandler = () async => throw Exception('offline');
    await auth.signOut();
    expect(auth.user?.uid, signedInUser.uid);
    expect(auth.message, contains('Could not sign out'));
  });

  test(
      'stream errors close the auth gate and late completions do not notify disposed UI',
      () async {
    final gateway = FakeAuthGateway();
    final auth = MobileAuthController(gateway);
    gateway.sessions.add(signedInUser);
    gateway.sessions.addError(StateError('stream failed'));
    expect(auth.ready, isTrue);
    expect(auth.user, isNull);
    final result = Completer<MobileAuthUser?>();
    gateway.signInHandler = () => result.future;
    final operation = auth.signIn();
    auth.dispose();
    result.complete(signedInUser);
    await operation;
    await gateway.sessions.close();
  });

  test('live account binds to UI without changing shared mock preferences',
      () async {
    final before = jsonEncode(await FigmaMockRepository.settingsData());
    final data = await FigmaMockRepository.settingsScreen(
        'M13', Brightness.dark,
        accountName: signedInUser.displayName,
        accountEmail: signedInUser.email);
    expect(data.layers[7]['v'], signedInUser.name);
    expect(data.layers[8]['v'], signedInUser.email);
    expect(jsonEncode(await FigmaMockRepository.settingsData()), before);
    expect(const MobileAuthUser(uid: 'empty', name: ' ', email: '').displayName,
        'Google account');
  });

  testWidgets(
      'real auth gates routes, restores, signs in, displays errors/profile and signs out',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      for (final id in ['M01', 'M02', 'M04', 'M09', 'M13']) {
        await FigmaMockRepository.screen(id, Brightness.dark);
        await FigmaMockRepository.hotspots(id);
      }
      await FigmaMockRepository.tokensScreen(Brightness.dark);
      await FigmaMockRepository.demoInteractions();
      for (final id in ['S02', 'S03']) {
        await FigmaMockRepository.syncScreen(id, Brightness.dark);
        await FigmaMockRepository.hotspots(id);
      }
      await FigmaMockRepository.settingsScreen('M13', Brightness.dark,
          accountName: signedInUser.displayName,
          accountEmail: signedInUser.email);
    });
    final gateway = FakeAuthGateway();
    final auth = MobileAuthController(gateway);
    final router = createAppRouter(auth: auth);
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    addTearDown(gateway.sessions.close);
    await tester.pumpWidget(ProviderScope(
        child: MobileAuthScope(
            controller: auth,
            child: UiPreviewScope(
                enabled: false,
                child: MaterialApp.router(
                    theme: ThemeData.dark(), routerConfig: router)))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(router.routeInformationProvider.value.uri.path, '/auth/loading');
    gateway.sessions.add(signedInUser);
    await settle(tester);
    expect(router.routeInformationProvider.value.uri.path, '/tokens');
    gateway.sessions.add(null);
    await settle(tester);
    expect(router.routeInformationProvider.value.uri.path, '/welcome');
    router.go('/account');
    await settle(tester);
    expect(router.routeInformationProvider.value.uri.path, '/welcome');

    Future<void> tapKey(String key) async {
      await tester.runAsync(() => tester.tap(find.byKey(ValueKey(key)).last));
      await settle(tester);
    }

    gateway.signInHandler = () async => null;
    await tapKey('figma-hotspot-Continue with Google');
    expect(find.textContaining('Sign-in was cancelled'), findsOneWidget);
    gateway.signInHandler =
        () async => throw const MobileAuthFailure('Network unavailable.');
    await tapKey('figma-hotspot-Continue with Google');
    expect(find.text('Network unavailable.'), findsOneWidget);
    gateway.signInHandler = null;
    await tapKey('figma-hotspot-Continue with Google');
    expect(router.routeInformationProvider.value.uri.path, '/connect-desktop');
    await tapKey('figma-hotspot-Back');
    expect(router.routeInformationProvider.value.uri.path, '/tokens');
    router.go('/connect-desktop');
    await settle(tester);
    await tapKey('figma-hotspot-I’ve paired my device');
    expect(
        router.routeInformationProvider.value.uri.path, '/waiting-first-usage');
    await tapKey('figma-hotspot-Refresh usage');
    expect(
        tester
            .widget<FigmaPixelScreen>(find.byType(FigmaPixelScreen).last)
            .screenId,
        'S03');
    await tapKey('mock-complete-sync');
    expect(router.routeInformationProvider.value.uri.path, '/tokens');
    await tapKey('figma-hotspot-Refresh');
    expect(router.routeInformationProvider.value.uri.path, '/tokens');
    await tapKey('figma-hotspot-Refresh');
    expect(router.canPop(), isFalse,
        reason: 'Live refresh must not push another Tokens page');
    router.go('/connect-desktop');
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(router.routeInformationProvider.value.uri.path, '/tokens');
    router.go('/account');
    await settle(tester);
    expect(find.text(signedInUser.email!), findsOneWidget);
    expect(find.text(signedInUser.name!), findsOneWidget);
    await tapKey('figma-hotspot-Sign out');
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(gateway.signOutCalls, 0);
    await tapKey('figma-hotspot-Sign out');
    await tester.runAsync(
        () => tester.tap(find.widgetWithText(FilledButton, 'Sign out')));
    await settle(tester);
    expect(gateway.signOutCalls, 1);
    expect(router.routeInformationProvider.value.uri.path, '/welcome');
    router.go('/tokens');
    await settle(tester);
    expect(router.routeInformationProvider.value.uri.path, '/welcome');
    expect(tester.takeException(), isNull);
  });
}
