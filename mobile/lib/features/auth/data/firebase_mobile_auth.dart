import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/mobile_auth.dart';

class FirebaseMobileAuth implements MobileAuthGateway {
  FirebaseMobileAuth({FirebaseAuth? auth, GoogleSignIn? google})
      : _auth = auth ?? FirebaseAuth.instance,
        _google = google ?? GoogleSignIn(scopes: ['email']);

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  MobileAuthUser? _profile(User? user) => user == null
      ? null
      : MobileAuthUser(
          uid: user.uid,
          email: user.email,
          name: user.displayName,
          photoUrl: user.photoURL);

  // Native Firebase Auth restores/persists the session and refreshes tokens.
  @override
  Stream<MobileAuthUser?> get sessionChanges =>
      _auth.authStateChanges().map(_profile);

  @override
  Future<MobileAuthUser?> signInWithGoogle() async {
    try {
      return await _signInWithGoogle();
    } on MobileAuthFailure {
      // Forget the cached Google account so the next attempt shows the picker
      // again instead of silently reusing the account that just failed.
      await _forgetGoogleAccount();
      rethrow;
    }
  }

  Future<void> _forgetGoogleAccount() async {
    try {
      await _google.signOut();
    } on PlatformException {
      // Best effort: the picker simply may not reappear.
    }
  }

  Future<MobileAuthUser?> _signInWithGoogle() async {
    try {
      final account = await _google.signIn();
      if (account == null) return null;
      final tokens = await account.authentication;
      if (tokens.idToken == null || tokens.idToken!.isEmpty) {
        throw const MobileAuthFailure(
            'Google sign-in is not configured. Check the Android package, SHA-1 and Firebase configuration.');
      }
      final result = await _auth.signInWithCredential(
          GoogleAuthProvider.credential(
              idToken: tokens.idToken, accessToken: tokens.accessToken));
      final user = _profile(result.user);
      if (user == null) {
        throw const MobileAuthFailure(
            'Google sign-in returned no account. Please try again.');
      }
      return user;
    } on FirebaseAuthException catch (error) {
      throw MobileAuthFailure(switch (error.code) {
        'network-request-failed' =>
          'No connection. Check your network and try again.',
        'user-disabled' =>
          'This account has been disabled. Contact your administrator.',
        'operation-not-allowed' =>
          'Google sign-in is not enabled for this Firebase project.',
        'account-exists-with-different-credential' =>
          'This email uses another sign-in provider.',
        'invalid-api-key' ||
        'app-not-authorized' =>
          'Firebase configuration does not match this Android app.',
        _ => 'Firebase could not complete sign-in. Please try again.',
      });
    } on PlatformException catch (error) {
      if (const ['sign_in_canceled', 'sign_in_cancelled']
          .contains(error.code)) {
        return null;
      }
      throw MobileAuthFailure(error.code == 'network_error'
          ? 'No connection. Check your network and try again.'
          : 'Google sign-in failed. Check Google Play services, the Android package and SHA-1, then retry.');
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _google.signOut();
    } on PlatformException {
      // The Firebase session is already cleared; Google picker cleanup is optional.
    }
  }
}
