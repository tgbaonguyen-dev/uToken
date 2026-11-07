import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, this._google);
  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  AuthUser _user(User user) => AuthUser(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
      );

  @override
  Stream<AuthUser?> get authStateChanges =>
      _auth.idTokenChanges().map((user) => user == null ? null : _user(user));

  @override
  Future<AuthUser?> signInWithGoogle() async {
    try {
      final account = await _google.signIn();
      if (account == null) return null; // Account chooser was dismissed.
      final tokens = await account.authentication;
      if (tokens.idToken == null || tokens.idToken!.isEmpty) {
        throw const AuthFailure('AUTH_CONFIG',
            'Google chưa được cấu hình cho ứng dụng này. Vui lòng liên hệ nhóm hỗ trợ.');
      }
      final result =
          await _auth.signInWithCredential(GoogleAuthProvider.credential(
        idToken: tokens.idToken,
        accessToken: tokens.accessToken,
      ));
      if (result.user == null) {
        throw const AuthFailure(
            'AUTH_INVALID', 'Không tạo được phiên đăng nhập. Hãy thử lại.');
      }
      return _user(result.user!);
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseError(error);
    } on PlatformException catch (error) {
      if (error.code == 'sign_in_canceled') return null;
      throw AuthFailure(
          error.code == 'network_error' ? 'AUTH_NETWORK' : 'AUTH_CONFIG',
          error.code == 'network_error'
              ? 'Không có kết nối mạng. Kiểm tra mạng và thử lại.'
              : 'Không đăng nhập được Google. Kiểm tra cấu hình ứng dụng và thử lại.');
    }
  }

  @override
  Future<String> getIdToken({bool forceRefresh = false}) async {
    try {
      final token = await _auth.currentUser?.getIdToken(forceRefresh);
      if (token == null || token.isEmpty) {
        throw const AuthFailure(
            'AUTH_INVALID', 'Session expired. Vui lòng đăng nhập lại.');
      }
      return token;
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseError(error);
    }
  }

  @override
  Future<void> signOut() async {
    // Clear the Firebase session even if the Google plugin cannot reach Play Services.
    await _auth.signOut();
    try {
      await _google.signOut();
    } on PlatformException {/* Firebase is already signed out. */}
  }

  AuthFailure _mapFirebaseError(FirebaseAuthException error) {
    switch (error.code) {
      case 'network-request-failed':
        return const AuthFailure(
            'AUTH_NETWORK', 'Không có kết nối mạng. Kiểm tra mạng và thử lại.');
      case 'user-token-expired':
      case 'invalid-user-token':
      case 'user-disabled':
      case 'user-not-found':
      case 'invalid-credential':
        return const AuthFailure(
            'AUTH_INVALID', 'Session expired. Vui lòng đăng nhập lại.');
      case 'account-exists-with-different-credential':
        return const AuthFailure('AUTH_ACCOUNT',
            'Email này đang dùng phương thức đăng nhập khác. Vui lòng liên hệ hỗ trợ.');
      default:
        return const AuthFailure(
            'AUTH_FAILED', 'Đăng nhập thất bại. Vui lòng thử lại.');
    }
  }
}
