import 'dart:async';

import 'package:flutter/widgets.dart';

class MobileAuthUser {
  const MobileAuthUser(
      {required this.uid, this.email, this.name, this.photoUrl});
  final String uid;
  final String? email;
  final String? name;
  final String? photoUrl;
  String get displayName => name?.trim().isNotEmpty == true
      ? name!.trim()
      : email?.trim().isNotEmpty == true
          ? email!.trim()
          : 'Google account';
}

abstract interface class MobileAuthGateway {
  Stream<MobileAuthUser?> get sessionChanges;
  Future<MobileAuthUser?> signInWithGoogle();
  Future<void> signOut();
}

class MobileAuthFailure implements Exception {
  const MobileAuthFailure(this.message);
  final String message;
}

class MobileAuthController extends ChangeNotifier {
  MobileAuthController(this.gateway) {
    _subscription = gateway.sessionChanges.listen((value) {
      if (value == null && user != null && !busy) {
        message = 'Session expired. Sign in with Google again.';
      }
      user = value;
      ready = true;
      notifyListeners();
    }, onError: (Object _) {
      ready = true;
      user = null;
      message = 'Could not restore your session. Please sign in again.';
      notifyListeners();
    });
  }

  final MobileAuthGateway gateway;
  late final StreamSubscription<MobileAuthUser?> _subscription;
  MobileAuthUser? user;
  bool ready = false;
  bool busy = false;
  bool demoMode = false;
  bool _disposed = false;
  String? message;
  String signedInDestination = '/tokens';

  void enterDemo() {
    demoMode = true;
    message = null;
    notifyListeners();
  }

  void exitDemo() {
    demoMode = false;
    notifyListeners();
  }

  Future<void> expireSession() async {
    if (_disposed || user == null) return;
    try {
      await gateway.signOut();
    } catch (_) {}
    if (_disposed) return;
    user = null;
    demoMode = false;
    busy = false;
    message = 'Session expired. Sign in with Google again.';
    notifyListeners();
  }

  // Ends only the UI onboarding route; this does not pair a desktop device.
  void leaveDesktopSetup() {
    signedInDestination = '/tokens';
  }

  void dismissMessage() {
    message = null;
    notifyListeners();
  }

  Future<void> signIn() async {
    if (busy) return;
    demoMode = false;
    busy = true;
    message = null;
    signedInDestination = '/tokens';
    notifyListeners();
    try {
      final result = await gateway.signInWithGoogle();
      if (_disposed) return;
      if (result == null) {
        message = 'Sign-in was cancelled. You can try again.';
      } else {
        user = result;
      }
    } on MobileAuthFailure catch (error) {
      if (!_disposed) message = error.message;
    } catch (_) {
      if (!_disposed) message = 'Sign-in could not complete. Please try again.';
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> signOut() async {
    if (busy) return;
    busy = true;
    message = null;
    notifyListeners();
    try {
      await gateway.signOut();
      if (!_disposed) user = null;
    } catch (_) {
      if (!_disposed) message = 'Could not sign out. Please try again.';
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    super.dispose();
  }
}

class MobileAuthScope extends InheritedNotifier<MobileAuthController> {
  const MobileAuthScope(
      {super.key,
      required MobileAuthController controller,
      required super.child})
      : super(notifier: controller);

  static MobileAuthController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MobileAuthScope>()?.notifier;
}
