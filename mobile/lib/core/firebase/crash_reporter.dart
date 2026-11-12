import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Crash reporting: forwards uncaught errors to Crashlytics and provides a
/// deliberate test crash that is also recorded in Firestore at
/// `users/{uid}/crash_reports/{id}`.
class CrashReporter {
  CrashReporter._();

  /// Signed-in account; uncaught errors are also logged under it so the admin
  /// console can list them (Crashlytics data is not readable from the web).
  static String? currentUid;
  static String appVersion = '';
  static final _sent = <String>{};
  static const _maxReportsPerLaunch = 5;

  /// Remembers who is signed in. Pure Dart, so it is safe in widget tests.
  static void bindUser(String? uid, {required String version}) {
    currentUid = uid;
    appVersion = version;
  }

  /// Best-effort Firestore copy of an uncaught error (deduplicated, capped).
  static Future<void> _logToFirestore(Object error, StackTrace? stack,
      {required bool fatal, String? context}) async {
    final uid = currentUid;
    final message = error.toString();
    if (uid == null || _sent.length >= _maxReportsPerLaunch) return;
    if (!_sent.add(message)) return;
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(uid);
      final trace = stack?.toString() ?? '';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('crash_reports')
          .add({
        'type': fatal ? 'fatal_error' : 'error',
        'platform': defaultTargetPlatform.name,
        'app_version': appVersion,
        'screen': context ?? '',
        'message': message.length > 500 ? message.substring(0, 500) : message,
        'stack': trace.length > 4000 ? trace.substring(0, 4000) : trace,
        'created_at': FieldValue.serverTimestamp(),
        'client_time': DateTime.now().toUtc().toIso8601String(),
      }).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Reporting must never throw from an error handler.
    }
  }

  /// Call once, right after `Firebase.initializeApp()`.
  static Future<void> install() async {
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(true);
    FlutterError.onError = (details) {
      // Keep the red screen and console output in debug builds.
      FlutterError.presentError(details);
      crashlytics.recordFlutterFatalError(details);
      unawaited(_logToFirestore(details.exception, details.stack,
          fatal: true, context: details.context?.toDescription()));
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      unawaited(_logToFirestore(error, stack, fatal: true));
      return true;
    };
  }

  static Future<void> setUser(String? uid) =>
      FirebaseCrashlytics.instance.setUserIdentifier(uid ?? '');

  /// Writes a crash report to Firestore, logs it to Crashlytics, then
  /// force-crashes the app natively. Does not return.
  static Future<void> triggerTestCrash({
    required String uid,
    required String appVersion,
    String screen = 'account',
  }) async {
    final crashlytics = FirebaseCrashlytics.instance;
    final doc = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('crash_reports')
        .doc();
    await crashlytics.setUserIdentifier(uid);
    await crashlytics.setCustomKey('crash_report_id', doc.id);
    await crashlytics.setCustomKey('screen', screen);
    crashlytics.log('Manual test crash from $screen (report ${doc.id})');
    try {
      // Firestore queues the write locally, so it survives the crash even if
      // the server ack has not arrived; it is flushed on next launch.
      await doc.set({
        'type': 'test_crash',
        'platform': defaultTargetPlatform.name,
        'app_version': appVersion,
        'screen': screen,
        'message': 'Manual test crash triggered from the mobile app',
        'created_at': FieldValue.serverTimestamp(),
        'client_time': DateTime.now().toUtc().toIso8601String(),
      }).timeout(const Duration(seconds: 3));
    } catch (_) {
      // Timeout or offline: the write stays queued locally.
    }
    crashlytics.crash();
  }
}
