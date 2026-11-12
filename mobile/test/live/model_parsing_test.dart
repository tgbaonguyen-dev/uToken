import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/core/models/daily_doc.dart';
import 'package:utoken_mobile/core/models/usage_docs.dart';

void main() {
  test('Firestore numeric values parse as int or double and preserve null', () {
    final doc = DailyDoc.fromMap({
      'schema_version': 2,
      'date': '2026-11-09',
      'totals': {'input': 1.0, 'context_growth_sum': 2},
    });

    expect(doc.totals.input, 1);
    expect(doc.totals.contextGrowthSum, 2.0);
    expect(doc.totals.costMicro, isNull);
    expect(doc.pricingVersion, isNull);
  });

  test('optional insight provider and model can be absent', () {
    final doc = InsightsDoc.fromMap({
      'status': 'ok',
      'insights': [
        {'id': 'M08'}
      ],
    });

    expect(doc.provider, isNull);
    expect(doc.model, isNull);
    expect(doc.insights.single.provider, isNull);
  });

  test('unsupported daily schema version is rejected for repository filtering',
      () {
    expect(
      () => DailyDoc.fromMap({'schema_version': 1}),
      throwsFormatException,
    );
  });
}
