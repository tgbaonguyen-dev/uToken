import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/daily_doc.dart';
import '../models/usage_docs.dart';

/// Read-only contract for usage documents owned by a signed-in user.
abstract interface class UsageRepository {
  Stream<List<DailyDoc>> watchDaily({
    required String uid,
    required DateTime start,
    required DateTime end,
  });

  Stream<EfficiencyDoc?> watchEfficiency({required String uid});
  Stream<InsightsDoc?> watchInsights({required String uid});
  Stream<DateTime?> watchLastSync({required String uid});
}

/// Firestore implementation of [UsageRepository]. It never writes documents.
class FirestoreUsageRepository implements UsageRepository {
  FirestoreUsageRepository({required this.firestore});

  final FirebaseFirestore firestore;

  DocumentReference<JsonMap> _user(String uid) =>
      firestore.collection('users').doc(uid);

  @override
  Stream<List<DailyDoc>> watchDaily({
    required String uid,
    required DateTime start,
    required DateTime end,
  }) {
    final query = _user(uid)
        .collection('daily')
        .orderBy(FieldPath.documentId)
        .startAt([_day(start)]).endAt([_day(end)]);
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

  String _day(DateTime value) => value.toIso8601String().substring(0, 10);
}
