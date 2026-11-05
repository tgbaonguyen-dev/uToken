import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/core/models/daily_doc.dart';

void main() {
  test('FR-ANLY-001: total = input + output', () {
    final b = TokenBreakdown.fromMap({'input': 100, 'cached': 40, 'cache_write': 0, 'output': 20, 'thinking': 10});
    expect(b.total, 120);
    expect(b.cacheHitRate, closeTo(0.4, 1e-9));
  });

  test('từ chối schema_version lạ', () {
    expect(() => DailyDoc.fromMap({'schema_version': 1}), throwsFormatException);
  });
}
