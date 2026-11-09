import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/core/models/daily_doc.dart';

void main() {
  test('FR-ANLY-001: total = input + output', () {
    final b = TokenBreakdown.fromMap({
      'input': 100,
      'cached': 40,
      'cache_write': 0,
      'output': 20,
      'thinking': 10
    });
    expect(b.total, 120);
    expect(b.cacheHitRate, closeTo(0.4, 1e-9));
  });

  test('từ chối schema_version lạ', () {
    expect(
        () => DailyDoc.fromMap({'schema_version': 1}), throwsFormatException);
  });

  test('reads integer and double Firestore numbers safely', () {
    final doc = DailyDoc.fromMap({
      'schema_version': 2,
      'date': '2026-11-09',
      'totals': {
        'input': 10.0,
        'cached': 4,
        'cache_write': 0,
        'output': 2.0,
        'cost_micro': null,
      },
    });
    expect(doc.totals.input, 10);
    expect(doc.totals.output, 2);
    expect(doc.totals.costMicro, isNull);
    expect(doc.byKey, isEmpty);
  });
}
