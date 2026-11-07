import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_repository.dart';

class AuthState {
  const AuthState(
      {this.user,
      this.initializing = false,
      this.busy = false,
      this.sessionExpired = false,
      this.message});
  final AuthUser? user;
  final bool initializing;
  final bool busy;
  final bool sessionExpired;
  final String? message;
  bool get signedIn => user != null;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository)
      : super(const AuthState(initializing: true)) {
    _subscription =
        _repository.authStateChanges.listen(_onUserChanged, onError: (_) {
      if (mounted) {
        state = const AuthState(
            message: 'Không đọc được phiên đăng nhập. Vui lòng thử lại.');
      }
    });
  }
  final AuthRepository _repository;
  late final StreamSubscription<AuthUser?> _subscription;
  bool _operating = false;
  bool _expired = false;
  int _revision = 0;

  void _onUserChanged(AuthUser? user) {
    if (!mounted) return;
    if (_expired) user = null;
    final initial = state.initializing;
    state = AuthState(
        user: user,
        busy: _operating,
        sessionExpired: user == null && _expired,
        message: user == null && _expired
            ? 'Session expired. Vui lòng đăng nhập lại.'
            : null);
    if (initial && user != null) unawaited(validateSession());
  }

  Future<void> signIn() async {
    if (_operating) return;
    _operating = true;
    _revision++;
    _expired = false;
    state = const AuthState(busy: true);
    try {
      final user = await _repository.signInWithGoogle();
      if (mounted) {
        state = AuthState(
            user: user,
            message: user == null ? 'Bạn đã hủy đăng nhập Google.' : null);
      }
    } on AuthFailure catch (error) {
      if (mounted) {
        state = AuthState(
            sessionExpired: error.isSessionExpired, message: error.message);
      }
    } catch (_) {
      if (mounted) {
        state =
            const AuthState(message: 'Đăng nhập thất bại. Vui lòng thử lại.');
      }
    } finally {
      _operating = false;
    }
  }

  Future<void> validateSession() async {
    if (!state.signedIn || _operating) return;
    final revision = _revision;
    try {
      await _repository.getIdToken(forceRefresh: true);
    } on AuthFailure catch (error) {
      if (!mounted || revision != _revision) return;
      if (error.isSessionExpired) {
        _expired = true;
        try {
          await _repository.signOut();
        } catch (_) {/* Keep local routes locked. */}
        if (!mounted || revision != _revision) return;
        if (mounted) {
          state = const AuthState(
              sessionExpired: true,
              message: 'Session expired. Vui lòng đăng nhập lại.');
        }
      } else {
        // A network outage does not erase the SDK's persisted session.
        state = AuthState(user: state.user, message: error.message);
      }
    } catch (_) {
      if (mounted && revision == _revision) {
        state = AuthState(
            user: state.user,
            message:
                'Không kiểm tra được phiên. Kiểm tra kết nối mạng và thử lại.');
      }
    }
  }

  Future<void> signOut() async {
    if (_operating) return;
    _operating = true;
    _revision++;
    final user = state.user;
    state = AuthState(user: user, busy: true);
    try {
      await _repository.signOut();
      _expired = false;
      if (mounted) state = const AuthState();
    } catch (_) {
      if (mounted) {
        state = AuthState(
            user: state.user,
            message: 'Chưa đăng xuất được. Vui lòng thử lại.');
      }
    } finally {
      _operating = false;
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
