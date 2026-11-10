import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:utoken_mobile/features/ai_review/judge.dart';

import 'live/live_screens_test.dart' show keyedDoc;

void main() {
  final now = DateTime(2026, 11, 11);
  final daily = [
    for (var i = 0; i < 4; i++)
      keyedDoc(now.subtract(Duration(days: i)), {'codex|gpt-5|none': 1000})
  ];

  test('brief only holds aggregate metrics with stable ids', () {
    final brief = buildBrief(daily, null, now: now);
    expect(brief.catalog['usage.chats']!.value, '12');
    expect(brief.catalog.keys, contains('usage.codex.gpt-5.tokens'));
    expect(brief.toJson(), isNot(contains('none'))); // no project keys
  });

  test('validation drops unknown metrics and clamps scores and savings', () {
    final brief = buildBrief(daily, null, now: now);
    final doc = validateOutput(
        jsonEncode({
          'score': 140,
          'grade': 'Z',
          'headline': 'h',
          'dimensions': [
            {'id': 'cache', 'score': -5, 'comment': 'c'},
            {'id': 'nope', 'score': 50, 'comment': 'x'},
          ],
          'insights': [
            {
              'id': 'a',
              'title': 't',
              'severity': 'high',
              'category': 'cache',
              'provider': 'codex',
              'evidence': [
                {'metric': 'usage.chats'}
              ],
              'recommendation': 'r',
              'estimated_impact': null,
              'estimated_saving_usd_per_month': 9999,
              'confidence': 'high'
            },
            {
              'id': 'b',
              'title': 'made up',
              'severity': 'low',
              'category': 'cache',
              'provider': null,
              'evidence': [
                {'metric': 'invented.metric'}
              ],
              'recommendation': 'r',
              'estimated_impact': null,
              'estimated_saving_usd_per_month': null,
              'confidence': 'low'
            },
          ],
        }),
        brief,
        provider: 'google',
        model: 'm',
        now: now);
    expect(doc['score'], 100);
    expect(doc['grade'], isNull);
    expect((doc['dimensions'] as List).single['score'], 0);
    final insights = doc['insights'] as List;
    expect(insights, hasLength(1));
    expect(insights.single['evidence'].single['value'], '12');
    // Saving can never exceed the real monthly cost.
    expect(insights.single['estimated_saving_micro_per_month'],
        brief.monthlyCostMicro);
  });

  test('provider errors map to shared codes', () async {
    final client = MockClient((_) async => http.Response('{}', 401));
    expect(
        () => runJudge(
            client: client,
            daily: daily,
            efficiency: null,
            provider: 'anthropic',
            model: 'claude-opus-5-5',
            apiKey: 'bad',
            language: 'English',
            now: now),
        throwsA(isA<JudgeException>()
            .having((e) => e.code, 'code', 'invalid_api_key')));
  });

  test('too little data skips the provider call', () async {
    var called = false;
    final client = MockClient((_) async {
      called = true;
      return http.Response('{}', 200);
    });
    final doc = await runJudge(
        client: client,
        daily: daily.take(1).toList(),
        efficiency: null,
        provider: 'google',
        model: 'm',
        apiKey: 'k',
        language: 'English',
        now: now);
    expect(doc['status'], 'insufficient_data');
    expect(called, isFalse);
  });
}
