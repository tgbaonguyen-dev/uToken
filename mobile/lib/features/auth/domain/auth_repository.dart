class AuthUser {
  const AuthUser({required this.uid, this.email, this.displayName});
  final String uid;
  final String? email;
  final String? displayName;
}

class AuthFailure implements Exception {
  const AuthFailure(this.code, this.message);
  final String code;
  final String message;
  bool get isSessionExpired => code == 'AUTH_INVALID';
}

abstract interface class AuthRepository {
  Stream<AuthUser?> get authStateChanges;
  Future<AuthUser?> signInWithGoogle();
  Future<String> getIdToken({bool forceRefresh = false});
  Future<void> signOut();
}
