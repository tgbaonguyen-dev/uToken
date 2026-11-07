import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/app/router.dart';
import 'package:utoken_mobile/core/firebase/providers.dart';
import 'package:utoken_mobile/features/auth/domain/auth_repository.dart';
import 'package:utoken_mobile/features/auth/presentation/auth_controller.dart';
import 'package:utoken_mobile/main.dart';

const user =
    AuthUser(uid: 'uid-a', email: 'a@example.test', displayName: 'Test User');

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.initialUser});
  final AuthUser? initialUser;
  final events = StreamController<AuthUser?>.broadcast();
  AuthUser? result = user;
  AuthFailure? failure;
  AuthFailure? tokenFailure;
  Completer<AuthUser?>? pending;
  int signInCalls = 0;
  int signOutCalls = 0;

  @override
  Stream<AuthUser?> get authStateChanges async* {
    yield initialUser;
    yield* events.stream;
  }

  @override
  Future<AuthUser?> signInWithGoogle() async {
    signInCalls++;
    if (failure != null) throw failure!;
    final signedInUser = pending == null ? result : await pending!.future;
    if (signedInUser != null) events.add(signedInUser);
    return signedInUser;
  }

  @override
  Future<String> getIdToken({bool forceRefresh = false}) async {
    if (tokenFailure != null) throw tokenFailure!;
    return 'firebase-id';
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    events.add(null);
  }
}

Future<void> settleEvents() => Future<void>.delayed(Duration.zero);

void main() {
  test(
      'route guard blocks all private routes until session is known and authenticated',
      () {
    for (final path in [
      '/tokens',
      '/analytics',
      '/insights',
      '/settings',
      '/account'
    ]) {
      expect(
          authRedirect(const AuthState(initializing: true), path), '/loading');
      expect(authRedirect(const AuthState(), path), '/welcome');
      expect(authRedirect(const AuthState(user: user), path), isNull);
    }
    expect(authRedirect(const AuthState(user: user), '/welcome'), '/tokens');
    expect(authRedirect(const AuthState(sessionExpired: true), '/account'),
        '/welcome');
  });

  test('sign-in, duplicate tap prevention and logout clear the user', () async {
    final repository = FakeAuthRepository()..pending = Completer<AuthUser?>();
    final controller = AuthController(repository);
    addTearDown(() {
      controller.dispose();
      repository.events.close();
    });
    await settleEvents();
    final first = controller.signIn();
    expect(controller.state.busy, isTrue);
    await controller.signIn();
    expect(repository.signInCalls, 1);
    repository.pending!.complete(user);
    await first;
    await settleEvents();
    expect(controller.state.user?.uid, 'uid-a');
    expect(controller.state.busy, isFalse);
    await controller.signOut();
    await settleEvents();
    expect(controller.state.user, isNull);
    expect(repository.signOutCalls, 1);
  });

  test('cancelled account chooser stays signed out and allows retry', () async {
    final repository = FakeAuthRepository()..result = null;
    final controller = AuthController(repository);
    addTearDown(() {
      controller.dispose();
      repository.events.close();
    });
    await settleEvents();
    await controller.signIn();
    expect(controller.state.signedIn, isFalse);
    expect(controller.state.busy, isFalse);
    expect(controller.state.message, contains('hủy'));
    repository.result = user;
    await controller.signIn();
    expect(controller.state.user?.uid, 'uid-a');
  });

  test('network failure presents a recoverable error', () async {
    final repository = FakeAuthRepository()
      ..failure = const AuthFailure('AUTH_NETWORK', 'Offline');
    final controller = AuthController(repository);
    addTearDown(() {
      controller.dispose();
      repository.events.close();
    });
    await settleEvents();
    await controller.signIn();
    expect(controller.state.message, 'Offline');
    expect(controller.state.busy, isFalse);
    expect(controller.state.signedIn, isFalse);
  });

  test(
      'revoked session signs out and preserves Session expired state after auth stream emits null',
      () async {
    final repository = FakeAuthRepository(initialUser: user)
      ..tokenFailure = const AuthFailure('AUTH_INVALID', 'Expired');
    final controller = AuthController(repository);
    addTearDown(() {
      controller.dispose();
      repository.events.close();
    });
    await settleEvents();
    await settleEvents();
    expect(controller.state.signedIn, isFalse);
    expect(controller.state.sessionExpired, isTrue);
    expect(controller.state.message, contains('Session expired'));
    expect(repository.signOutCalls, 1);
  });

  test('network outage during restored-session validation keeps user signed in',
      () async {
    final repository = FakeAuthRepository(initialUser: user)
      ..tokenFailure = const AuthFailure('AUTH_NETWORK', 'Offline');
    final controller = AuthController(repository);
    addTearDown(() {
      controller.dispose();
      repository.events.close();
    });
    await settleEvents();
    expect(controller.state.user?.uid, 'uid-a');
    expect(controller.state.message, 'Offline');
    expect(repository.signOutCalls, 0);
  });

  testWidgets('welcome -> Google login -> account -> logout returns to welcome',
      (tester) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.events.close);
    await tester.pumpWidget(ProviderScope(overrides: [
      authRepositoryProvider.overrideWithValue(repository),
    ], child: const UTokenApp()));
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Tokens'), findsNothing);
    await tester.tap(find.byKey(const Key('google-sign-in')));
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsNothing);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(find.text('a@example.test'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('a@example.test'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
