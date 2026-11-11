import '../models/usage_docs.dart';
import 'replay_stream.dart';
import 'usage_repository.dart';

/// Wraps a [UsageRepository] so each watched document has one shared,
/// replaying listener (see [ReplayStream]). Writes and one-off sync request
/// streams go straight through.
class CachedUsageRepository implements UsageRepository {
  CachedUsageRepository(this.inner);
  final UsageRepository inner;
  final _streams = <String, ReplayStream<Object?>>{};

  Stream<T> _cached<T>(String key, Stream<T> Function() open) =>
      _streams.putIfAbsent(key, () => ReplayStream<T>(open)) as ReplayStream<T>;

  @override
  Stream<DailySnapshot> watchDaily(
          {required String uid, DateTime? start, DateTime? end}) =>
      _cached('daily/$uid/$start/$end',
          () => inner.watchDaily(uid: uid, start: start, end: end));

  @override
  Stream<EfficiencyDoc?> watchEfficiency({required String uid}) =>
      _cached('eff/$uid', () => inner.watchEfficiency(uid: uid));

  @override
  Stream<InsightsDoc?> watchInsights({required String uid}) =>
      _cached('ins/$uid', () => inner.watchInsights(uid: uid));

  @override
  Stream<DateTime?> watchLastSync({required String uid}) =>
      _cached('sync/$uid', () => inner.watchLastSync(uid: uid));

  @override
  Stream<bool> watchOffline({required String uid}) =>
      inner.watchOffline(uid: uid);

  @override
  Stream<String?> watchDesktopName({required String uid}) =>
      _cached('desk/$uid', () => inner.watchDesktopName(uid: uid));

  @override
  Future<void> touchProfile(
          {required String uid,
          String? email,
          String? name,
          required String appVersion,
          required String platform}) =>
      inner.touchProfile(
          uid: uid,
          email: email,
          name: name,
          appVersion: appVersion,
          platform: platform);

  @override
  Stream<Map<String, String>> watchProjectNames({required String uid}) =>
      _cached('proj/$uid', () => inner.watchProjectNames(uid: uid));

  @override
  Stream<Map<String, dynamic>?> watchPreferences({required String uid}) =>
      _cached('prefs/$uid', () => inner.watchPreferences(uid: uid));

  @override
  Stream<SyncRequestStatus?> watchSyncRequest(
          {required String uid, required String id}) =>
      inner.watchSyncRequest(uid: uid, id: id);

  @override
  Future<void> refresh({required String uid}) => inner.refresh(uid: uid);

  @override
  Future<String> requestSync(
          {required String uid, String trigger = 'manual_refresh'}) =>
      inner.requestSync(uid: uid, trigger: trigger);

  @override
  Future<void> saveInsights(
          {required String uid,
          required Map<String, dynamic> values,
          bool merge = false}) =>
      inner.saveInsights(uid: uid, values: values, merge: merge);

  @override
  Future<void> savePreferences(
          {required String uid, required Map<String, dynamic> values}) =>
      inner.savePreferences(uid: uid, values: values);
}
