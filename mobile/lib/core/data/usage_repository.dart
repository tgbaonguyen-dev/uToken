import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/daily_doc.dart';
import '../models/usage_docs.dart';
abstract interface class UsageRepository { Stream<List<DailyDoc>> watchDaily({required String uid, required DateTime start, required DateTime end}); Future<EfficiencyDoc?> readEfficiency({required String uid}); Future<InsightsDoc?> readInsights({required String uid}); Stream<DateTime?> watchLastSync({required String uid}); }
class FirestoreUsageRepository implements UsageRepository {
  FirestoreUsageRepository({required this.firestore});
  final FirebaseFirestore firestore;
  DocumentReference<JsonMap> _user(String uid) => firestore.collection('users').doc(uid);
  @override Stream<List<DailyDoc>> watchDaily({required String uid, required DateTime start, required DateTime end}) => _user(uid).collection('daily').snapshots().map((s) => s.docs.map((d) => DailyDoc.fromMap({...d.data(), 'date': d.data()['date'] ?? d.id})).where((d) => d.date.compareTo(_day(start)) >= 0 && d.date.compareTo(_day(end)) <= 0).toList()..sort((a, b) => a.date.compareTo(b.date)));
  @override Future<EfficiencyDoc?> readEfficiency({required String uid}) async { final s = await _user(uid).collection('efficiency').doc('current').get(); return s.exists && s.data() != null ? EfficiencyDoc.fromMap(s.data()!) : null; }
  @override Future<InsightsDoc?> readInsights({required String uid}) async { final s = await _user(uid).collection('insights').doc('current').get(); return s.exists && s.data() != null ? InsightsDoc.fromMap(s.data()!) : null; }
  @override Stream<DateTime?> watchLastSync({required String uid}) => _user(uid).snapshots().map((s) { final v = s.data()?['last_sync_at']; return v is Timestamp ? v.toDate() : v is String ? DateTime.tryParse(v) : null; });
  String _day(DateTime d) => d.toIso8601String().substring(0, 10);
}
FirestoreUsageRepository defaultUsageRepository() => FirestoreUsageRepository(firestore: FirebaseFirestore.instance);
