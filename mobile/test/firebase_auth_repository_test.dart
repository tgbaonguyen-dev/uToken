import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:utoken_mobile/features/auth/data/firebase_auth_repository.dart';
import 'package:utoken_mobile/features/auth/domain/auth_repository.dart';

// Exercise the production repository at its SDK boundary, with no native login,
// Firebase project, saved Google account or real token involved.
class FakeFirebase extends Fake implements FirebaseAuth {
  User? user = FakeUser();
  AuthCredential? credential;
  FirebaseAuthException? error;
  int signInCalls = 0;
  int signOutCalls = 0;
  @override
  User? get currentUser => user;
  @override
  Stream<User?> idTokenChanges() => Stream.value(user);
  @override
  Future<UserCredential> signInWithCredential(AuthCredential value) async {
    signInCalls++;
    credential = value;
    if (error != null) throw error!;
    return FakeCredential(user);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    user = null;
  }
}

class FakeUser extends Fake implements User {
  bool refreshed = false;
  FirebaseAuthException? error;
  @override
  String get uid => 'firebase-uid';
  @override
  String? get email => 'qa@example.test';
  @override
  String? get displayName => 'QA';
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    refreshed = forceRefresh;
    if (error != null) throw error!;
    return 'firebase-id-token';
  }
}

class FakeCredential extends Fake implements UserCredential {
  FakeCredential(this.user);
  @override
  final User? user;
}

class FakeGoogle extends Fake implements GoogleSignIn {
  GoogleSignInAccount? account = FakeAccount('google-id-token');
  PlatformException? error;
  int signOutCalls = 0;
  @override
  Future<GoogleSignInAccount?> signIn() async {
    if (error != null) throw error!;
    return account;
  }

  @override
  Future<GoogleSignInAccount?> signOut() async {
    signOutCalls++;
    if (error != null) throw error!;
    return null;
  }
}

class FakeAccount extends Fake implements GoogleSignInAccount {
  FakeAccount(this.token);
  final String? token;
  @override
  Future<GoogleSignInAuthentication> get authentication async =>
      FakeTokens(token);
}

class FakeTokens extends Fake implements GoogleSignInAuthentication {
  FakeTokens(this.idToken);
  @override
  final String? idToken;
  @override
  String? get accessToken => 'google-access-token';
}

Matcher failure(String code) =>
    isA<AuthFailure>().having((e) => e.code, 'code', code);

void main() {
  test(
      'Google credential is exchanged and the Firebase UID identifies the user',
      () async {
    final firebase = FakeFirebase();
    final repository = FirebaseAuthRepository(firebase, FakeGoogle());
    final user = await repository.signInWithGoogle();
    expect(user?.uid, 'firebase-uid');
    expect(user?.email, 'qa@example.test');
    final credential = firebase.credential! as OAuthCredential;
    expect(credential.providerId, 'google.com');
    expect(credential.idToken, 'google-id-token');
    expect(credential.accessToken, 'google-access-token');
    expect((await repository.authStateChanges.first)?.uid, 'firebase-uid');
  });

  test('canceling Google never creates a Firebase session', () async {
    final firebase = FakeFirebase();
    final google = FakeGoogle()..account = null;
    expect(await FirebaseAuthRepository(firebase, google).signInWithGoogle(),
        isNull);
    expect(firebase.signInCalls, 0);
  });

  for (final token in <String?>[null, '']) {
    test(
        'missing Google ID token cannot fall back to access-token-only login: $token',
        () async {
      final firebase = FakeFirebase();
      final google = FakeGoogle()..account = FakeAccount(token);
      await expectLater(
          FirebaseAuthRepository(firebase, google).signInWithGoogle(),
          throwsA(failure('AUTH_CONFIG')));
      expect(firebase.signInCalls, 0);
    });
  }

  test('Google cancellation exception is recoverable', () async {
    final firebase = FakeFirebase();
    final google = FakeGoogle()
      ..error = PlatformException(code: 'sign_in_canceled');
    expect(await FirebaseAuthRepository(firebase, google).signInWithGoogle(),
        isNull);
    expect(firebase.signInCalls, 0);
  });

  test(
      'Google network failure is reported without leaking the platform message',
      () async {
    final google = FakeGoogle()
      ..error = PlatformException(
          code: 'network_error', message: 'private-provider-diagnostic');
    try {
      await FirebaseAuthRepository(FakeFirebase(), google).signInWithGoogle();
      fail('Expected a recoverable failure');
    } on AuthFailure catch (error) {
      expect(error.code, 'AUTH_NETWORK');
      expect(error.message, isNot(contains('private-provider-diagnostic')));
    }
  });

  test('invalid Firebase credential maps to Session expired', () async {
    final firebase = FakeFirebase()
      ..error = FirebaseAuthException(
          code: 'invalid-credential', message: 'private-token');
    await expectLater(
        FirebaseAuthRepository(firebase, FakeGoogle()).signInWithGoogle(),
        throwsA(failure('AUTH_INVALID')));
  });

  test('refresh is delegated to Firebase SDK', () async {
    final firebase = FakeFirebase();
    expect(
        await FirebaseAuthRepository(firebase, FakeGoogle())
            .getIdToken(forceRefresh: true),
        'firebase-id-token');
    expect((firebase.user! as FakeUser).refreshed, isTrue);
  });

  test('no current user cannot obtain an ID token', () async {
    final firebase = FakeFirebase()..user = null;
    await expectLater(
        FirebaseAuthRepository(firebase, FakeGoogle()).getIdToken(),
        throwsA(failure('AUTH_INVALID')));
  });

  test('network outage during refresh is recoverable', () async {
    final firebase = FakeFirebase();
    (firebase.user! as FakeUser).error =
        FirebaseAuthException(code: 'network-request-failed');
    await expectLater(
        FirebaseAuthRepository(firebase, FakeGoogle()).getIdToken(),
        throwsA(failure('AUTH_NETWORK')));
    expect(firebase.user, isNotNull);
  });

  test('Firebase session is cleared even if Google sign-out throws', () async {
    final firebase = FakeFirebase();
    final google = FakeGoogle()
      ..error = PlatformException(code: 'network_error');
    await FirebaseAuthRepository(firebase, google).signOut();
    expect(firebase.user, isNull);
    expect(firebase.signOutCalls, 1);
    expect(google.signOutCalls, 1);
  });
}
