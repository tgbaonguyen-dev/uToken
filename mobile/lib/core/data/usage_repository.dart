import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/daily_doc.dart';
import '../models/usage_docs.dart';

/// Usage reads and sync-request/preferences writes for the signed-in user.
abstract interface class UsageRepository {
  /// Explicitly read the server; offline/cache-only reads must not report success.
  Future<void> refresh({required String uid});
  Stream<DailySnapshot> watchDaily({
    required String uid,
    DateTime? start,
    DateTime? end,
  });

  Stream<EfficiencyDoc?> watchEfficiency({required String uid});
  Stream<InsightsDoc?> watchInsights({required String uid});
  Stream<DateTime?> watchLastSync({required String uid});

  /// True while Firestore can only serve cached data (no connection).
  Stream<bool> watchOffline({required String uid});

  /// Name the desktop reported on its last upload (users/{uid}.desktop_name).
  Stream<String?> watchDesktopName({required String uid});

  /// project_key → folder name the desktop shares (users/{uid}/meta/projects).
  /// Empty when the desktop keeps names private.
  Stream<Map<String, String>> watchProjectNames({required String uid});

  /// Active admin notices for this account, newest first.
  Stream<List<Notice>> watchNotices({required String uid});

  /// Records who this account is and that the phone app was opened, so the
  /// admin console can list users (merged into users/{uid}).
  Future<void> touchProfile(
      {required String uid,
      String? email,
      String? name,
      required String appVersion,
      required String platform});

  /// Asks the signed-in desktop to scan and upload now; returns the request id.
  /// [trigger] `ai_review` also makes the desktop run a fresh AI review.
  Future<String> requestSync(
      {required String uid, String trigger = 'manual_refresh'});

  /// State of a sync request: pending, running, done or failed.
  Stream<SyncRequestStatus?> watchSyncRequest(
      {required String uid, required String id});

  /// Writes users/{uid}/insights/current (phone AI review, FR-RECO-001).
  Future<void> saveInsights(
      {required String uid,
      required Map<String, dynamic> values,
      bool merge = false});

  /// Account preferences shared by every phone (users/{uid}/preferences/mobile).
  Stream<Map<String, dynamic>?> watchPreferences({required String uid});
  Future<void> savePreferences(
      {required String uid, required Map<String, dynamic> values});
}

class SyncRequestStatus {
  const SyncRequestStatus({required this.state, this.errorCode});
  final String state;
  final String? errorCode;
  factory SyncRequestStatus.fromMap(JsonMap values) {
    final state = readString(values['state']) ?? 'pending';
    if (!const {'pending', 'running', 'done', 'failed'}.contains(state)) {
      throw const FormatException('Unsupported sync request state.');
    }
    return SyncRequestStatus(
        state: state, errorCode: readString(values['error_code']));
  }
  bool get finished => state == 'done' || state == 'failed';
}

class DailySnapshot {
  const DailySnapshot(this.documents, {this.invalidDocumentIds = const []});
  final List<DailyDoc> documents;
  final List<String> invalidDocumentIds;
}

/// A normal read-only daily list retaining validation warnings for all live pages.
class DailyDocuments extends ListBase<DailyDoc> {
  DailyDocuments(DailySnapshot snapshot)
      : _values = List.unmodifiable(snapshot.documents),
        invalidDocumentIds = List.unmodifiable(snapshot.invalidDocumentIds);
  final List<DailyDoc> _values;
  final List<String> invalidDocumentIds;
  @override
  int get length => _values.length;
  @override
  set length(int value) =>
      throw UnsupportedError('Daily documents are read-only.');
  @override
  DailyDoc operator [](int index) => _values[index];
  @override
  void operator []=(int index, DailyDoc value) =>
      throw UnsupportedError('Daily documents are read-only.');
}

String? parseDesktopName(JsonMap? values) =>
    readString(values?['desktop_name']);

/// Used for both Firestore snapshots and console-edit regression tests.
DailySnapshot parseDailySnapshot(Map<String, JsonMap> values) {
  final documents = <DailyDoc>[];
  final invalid = <String>[];
  for (final entry in values.entries) {
    try {
      documents.add(DailyDoc.fromMap({
        ...entry.value,
        'date': entry.value['date'] ?? entry.key,
      }));
    } on FormatException {
      invalid.add(entry.key);
      developer.log('Ignoring invalid daily document',
          name: 'utoken.firestore');
    }
  }
  return DailySnapshot(documents, invalidDocumentIds: invalid);
}

/// Firestore usage reader; writes sync requests, preferences and phone AI reviews.
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
  Stream<DailySnapshot> watchDaily({
    required String uid,
    DateTime? start,
    DateTime? end,
  }) {
    Query<JsonMap> query =
        _user(uid).collection('daily').orderBy(FieldPath.documentId);
    if (end != null) query = query.endAt([_day(end)]);
    if (start != null) query = query.startAt([_day(start)]);
    return query.snapshots().map((snapshot) => parseDailySnapshot({
          for (final document in snapshot.docs) document.id: document.data(),
        }));
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
  Stream<bool> watchOffline({required String uid}) => _user(uid)
      .snapshots(includeMetadataChanges: true)
      .map((s) => s.metadata.isFromCache)
      .distinct();

  @override
  Stream<String?> watchDesktopName({required String uid}) => _user(uid)
      .snapshots()
      .map((snapshot) => parseDesktopName(snapshot.data()));

  @override
  Future<void> touchProfile(
          {required String uid,
          String? email,
          String? name,
          required String appVersion,
          required String platform}) =>
      _user(uid).set({
        if (email != null) 'email': email,
        if (name != null) 'display_name': name,
        'mobile_app_version': appVersion,
        'mobile_platform': platform,
        'last_seen_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  @override
  Stream<List<Notice>> watchNotices({required String uid}) {
    // Two live queries (broadcast + personal inbox) merged into one list.
    late final StreamController<List<Notice>> out;
    var broadcast = const <Notice>[], personal = const <Notice>[];
    var ready = 0;
    final subs = <StreamSubscription<Object?>>[];
    void emit() {
      if (ready < 2) return;
      final now = DateTime.now();
      out.add([...broadcast, ...personal].where((n) => n.isLive(now)).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0))));
    }

    List<Notice> parse(QuerySnapshot<Map<String, dynamic>> s, bool mine) => [
          for (final d in s.docs) Notice.fromMap(d.id, d.data(), personal: mine)
        ];
    out = StreamController<List<Notice>>(
      onListen: () {
        var gotB = false, gotP = false;
        subs.add(FirebaseFirestore.instance
            .collection('announcements')
            .where('active', isEqualTo: true)
            .snapshots()
            .listen((s) {
          broadcast = parse(s, false);
          if (!gotB) {
            gotB = true;
            ready++;
          }
          emit();
        }, onError: out.addError));
        subs.add(_user(uid)
            .collection('inbox')
            .where('active', isEqualTo: true)
            .snapshots()
            .listen((s) {
          personal = parse(s, true);
          if (!gotP) {
            gotP = true;
            ready++;
          }
          emit();
        }, onError: out.addError));
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return out.stream;
  }

  @override
  Stream<Map<String, String>> watchProjectNames({required String uid}) =>
      _user(uid).collection('meta').doc('projects').snapshots().map((s) {
        final names = s.data()?['names'];
        return names is Map
            ? {
                for (final e in names.entries)
                  if (e.value is String && (e.value as String).isNotEmpty)
                    '${e.key}': e.value as String
              }
            : const <String, String>{};
      });

  @override
  Future<String> requestSync(
      {required String uid, String trigger = 'manual_refresh'}) async {
    final doc = await _user(uid).collection('sync_requests').add({
      'trigger': trigger,
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
        return SyncRequestStatus.fromMap(data);
      });

  @override
  Future<void> saveInsights(
          {required String uid,
          required Map<String, dynamic> values,
          bool merge = false}) =>
      _user(uid)
          .collection('insights')
          .doc('current')
          .set(values, SetOptions(merge: merge));

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
