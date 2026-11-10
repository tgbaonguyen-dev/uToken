import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/daily_doc.dart';
import '../models/usage_docs.dart';

/// Read-only contract for usage documents owned by a signed-in user.
abstract interface class UsageRepository {
  /// Explicitly read the server; offline/cache-only reads must not report success.
  Future<void> refresh({required String uid});
  Stream<List<DailyDoc>> watchDaily({
    required String uid,
    DateTime? start,
    required DateTime end,
  });

  Stream<EfficiencyDoc?> watchEfficiency({required String uid});
  Stream<InsightsDoc?> watchInsights({required String uid});
  Stream<DateTime?> watchLastSync({required String uid});

  /// Name the desktop reported on its last upload (users/{uid}.desktop_name).
  Stream<String?> watchDesktopName({required String uid});

  /// Asks the signed-in desktop to scan and upload now; returns the request id.
  Future<String> requestSync({required String uid});

  /// State of a sync request: pending, running, done or failed.
  Stream<SyncRequestStatus?> watchSyncRequest(
      {required String uid, required String id});

  /// Account preferences shared by every phone (users/{uid}/preferences/mobile).
  Stream<Map<String, dynamic>?> watchPreferences({required String uid});
  Future<void> savePreferences(
      {required String uid, required Map<String, dynamic> values});
}

class SyncRequestStatus {
  const SyncRequestStatus({required this.state, this.errorCode});
  final String state;
  final String? errorCode;
  bool get finished => state == 'done' || state == 'failed';
}

/// Firestore implementation of [UsageRepository]. It never writes documents.
class FirestoreUsageRepository implements UsageRepository {
  FirestoreUsageRepository({required this.firestore});

  final FirebaseFirestore firestore;

  DocumentReference<JsonMap> _user(String uid) =>
      firestore.collection('users').doc(uid);

  @override
  Future<void> refresh({required String uid}) async {
    final user = _user(uid);
    const server = GetOptions(source: Source.server);
    await Future.wait([
      user.get(server),
      user.collection('daily').orderBy(FieldPath.documentId).get(server),
      user.collection('efficiency').doc('current').get(server),
      user.collection('insights').doc('current').get(server),
    ]);
  }

  @override
  Stream<List<DailyDoc>> watchDaily({
    required String uid,
    DateTime? start,
    required DateTime end,
  }) {
    var query = _user(uid)
        .collection('daily')
        .orderBy(FieldPath.documentId)
        .endAt([_day(end)]);
    if (start != null) query = query.startAt([_day(start)]);
    return query.snapshots().map((snapshot) {
      final documents = <DailyDoc>[];
      for (final document in snapshot.docs) {
        try {
          documents.add(DailyDoc.fromMap({
            ...document.data(),
            'date': document.data()['date'] ?? document.id,
          }));
        } on FormatException catch (error, stackTrace) {
          developer.log(
            'Ignoring invalid daily document',
            name: 'utoken.firestore',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
      return documents;
    });
  }

  @override
  Stream<EfficiencyDoc?> watchEfficiency({required String uid}) =>
      _user(uid).collection('efficiency').doc('current').snapshots().map(
            (snapshot) => snapshot.exists && snapshot.data() != null
                ? EfficiencyDoc.fromMap(snapshot.data()!)
                : null,
          );

  @override
  Stream<InsightsDoc?> watchInsights({required String uid}) =>
      _user(uid).collection('insights').doc('current').snapshots().map(
            (snapshot) => snapshot.exists && snapshot.data() != null
                ? InsightsDoc.fromMap(snapshot.data()!)
                : null,
          );

  @override
  Stream<DateTime?> watchLastSync({required String uid}) =>
      _user(uid).snapshots().map((snapshot) {
        final value = snapshot.data()?['last_sync_at'];
        return value is Timestamp
            ? value.toDate()
            : value is String
                ? DateTime.tryParse(value)
                : null;
      });

  @override
  Stream<String?> watchDesktopName({required String uid}) => _user(uid)
      .snapshots()
      .map((snapshot) => snapshot.data()?['desktop_name'] as String?);

  @override
  Future<String> requestSync({required String uid}) async {
    final doc = await _user(uid).collection('sync_requests').add({
      'trigger': 'manual_refresh',
      'state': 'pending',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    return doc.id;
  }

  @override
  Stream<SyncRequestStatus?> watchSyncRequest(
          {required String uid, required String id}) =>
      _user(uid).collection('sync_requests').doc(id).snapshots().map((s) {
        final data = s.data();
        if (data == null) return null;
        return SyncRequestStatus(
            state: data['state'] as String? ?? 'pending',
            errorCode: data['error_code'] as String?);
      });

  DocumentReference<JsonMap> _prefs(String uid) =>
      _user(uid).collection('preferences').doc('mobile');

  @override
  Stream<Map<String, dynamic>?> watchPreferences({required String uid}) =>
      _prefs(uid).snapshots().map((s) => s.data());

  @override
  Future<void> savePreferences(
          {required String uid, required Map<String, dynamic> values}) =>
      _prefs(uid).set(values, SetOptions(merge: true));

  String _day(DateTime value) => value.toIso8601String().substring(0, 10);
}
