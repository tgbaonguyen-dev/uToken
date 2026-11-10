import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Crash reporting: forwards uncaught errors to Crashlytics and provides a
/// deliberate test crash that is also recorded in Firestore at
/// `users/{uid}/crash_reports/{id}`.
class CrashReporter {
  CrashReporter._();

  /// Call once, right after `Firebase.initializeApp()`.
  static Future<void> install() async {
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(true);
    FlutterError.onError = (details) {
      // Keep the red screen and console output in debug builds.
      FlutterError.presentError(details);
      crashlytics.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
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
