import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/data/usage_aggregates.dart';
import '../../core/models/daily_doc.dart';
import '../../core/models/usage_docs.dart';

/// AI review that runs on the phone (SRS FR-RECO-001): the phone builds a
/// brief from the Firestore summaries, calls the provider with the user's own
/// key, checks every cited number against the brief and returns an insights
/// document in the same shape the desktop writes.

const judgeCategories = {
  'cache',
  'context',
  'reasoning',
  'reliability',
  'outcomes',
  'hidden_cost'
};
const _levels = {'high', 'medium', 'low'};
const _tools = {'codex', 'claude_code', 'antigravity'};

/// Supported providers and their default models.
const judgeProviders = ['google', 'anthropic', 'openai'];
String defaultJudgeModel(String provider) => switch (provider) {
      'anthropic' => 'claude-opus-5-5',
      'openai' => 'gpt-6-luna',
      _ => 'gemini-flash-latest',
    };

String judgeSystemPrompt(String language) => '''
You review how a developer uses AI coding tokens. Score 6 dimensions:
cache, context, reasoning, reliability, outcomes, hidden_cost (0–100 each, plus an
overall score and grade A–D). Only cite metric ids present in the catalog and never
invent numbers. Do not decide which setup is better: setup verdicts come from the
catalog and must not be changed. Every insight must cite at least one metric.
Write every text field in clear, concise $language: a short headline, plain-language
titles, a one-sentence comment per dimension, and one actionable recommendation per
insight. For each insight also give "why": one or two sentences on how this pattern
wastes tokens or money for this developer, and "steps": 2-4 short, concrete actions
they can take in their tool (settings, prompt habits, commands), in order. At most 5
insights, ordered by impact. Base savings estimates only on real
costs in the catalog.''';

/// Strict structured-output schema shared by all providers.
final Map<String, dynamic> judgeSchema = {
  'type': 'object',
  'additionalProperties': false,
  'required': ['score', 'grade', 'headline', 'dimensions', 'insights'],
  'properties': {
    'score': {
      'type': ['integer', 'null']
    },
    'grade': {
      'type': ['string', 'null'],
      'enum': ['A', 'B', 'C', 'D', null]
    },
    'headline': {'type': 'string'},
    'dimensions': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'required': ['id', 'score', 'comment'],
        'properties': {
          'id': {'enum': judgeCategories.toList()},
          'score': {
            'type': ['integer', 'null']
          },
          'comment': {'type': 'string'},
        },
      },
    },
    'insights': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'required': [
          'id',
          'title',
          'severity',
          'category',
          'provider',
          'evidence',
          'recommendation',
          'estimated_impact',
          'estimated_saving_usd_per_month',
          'confidence',
          'why',
          'steps'
        ],
        'properties': {
          'id': {'type': 'string'},
          'title': {'type': 'string'},
          'severity': {'enum': _levels.toList()},
          'category': {'enum': judgeCategories.toList()},
          'provider': {
            'type': ['string', 'null'],
            'enum': [..._tools, null]
          },
          'evidence': {
            'type': 'array',
            'items': {
              'type': 'object',
              'additionalProperties': false,
              'required': ['metric'],
              'properties': {
                'metric': {'type': 'string'}
              },
            },
          },
          'recommendation': {'type': 'string'},
          'estimated_impact': {
            'type': ['string', 'null']
          },
          'estimated_saving_usd_per_month': {
            'type': ['number', 'null']
          },
          'confidence': {'enum': _levels.toList()},
          'why': {'type': 'string'},
          'steps': {
            'type': 'array',
            'maxItems': 4,
            'items': {'type': 'string'}
          },
        },
      },
    },
  },
};

/// One metric the model may cite: readable label and display value.
class BriefMetric {
  const BriefMetric(this.label, this.value);
  final String label, value;
  Map<String, String> toJson() => {'label': label, 'value': value};
}

class JudgeBrief {
  JudgeBrief(
      {required this.periodStart,
      required this.periodEnd,
      required this.catalog,
      required this.chats,
      required this.requests,
      required this.monthlyCostMicro,
      this.pricingVersion = 'unknown'});
  final String periodStart, periodEnd;
  final Map<String, BriefMetric> catalog;
  final int chats, requests, monthlyCostMicro;
  final String pricingVersion;

  String toJson() => jsonEncode({
        'period_start': periodStart,
        'period_end': periodEnd,
        'catalog': catalog.map((k, v) => MapEntry(k, v.toJson())),
      });
}

String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
String _usd(int micro) => '${(micro / 1e6).toStringAsFixed(2)} USD';

/// Builds the catalog from the last 30 days of daily summaries and the
/// desktop's efficiency report (same metric ids as the desktop judge).
JudgeBrief buildBrief(List<DailyDoc> all, EfficiencyDoc? efficiency,
    {DateTime? now, DateTime? since}) {
  final today = now ?? DateTime.now();
  final docs = since == null ? filterLastDays(all, 30, today) : all;
  final t = sumTotals(docs);
  final c = <String, BriefMetric>{};
  void add(String id, String label, String value) =>
      c[id] = BriefMetric(label, value);
  add('usage.chats', 'Chats', '${t.chats}');
  add('usage.requests', 'Requests', '${t.requests}');
  add('usage.input_tokens', 'Input tokens', '${t.input}');
  add('usage.cached_tokens', 'Cached tokens', '${t.cached}');
  add('usage.output_tokens', 'Output tokens', '${t.output}');
  add('usage.cost_micro', since == null ? 'Monthly cost' : 'Period cost',
      t.costKnown ? _usd(t.cost) : 'N/A');
  add('usage.cache_hit_rate', 'Cache hit rate',
      t.input == 0 ? 'N/A' : _pct(t.cached / t.input));
  add('usage.error_rate', 'Error request rate',
      t.requests == 0 ? 'N/A' : _pct(t.errorRequests / t.requests));
  final o = sumOutcomes(docs);
  if (since == null) {
    add('outcome.success_rate', 'Success rate',
        o.successRate == null ? 'N/A' : _pct(o.successRate!));
    add('outcome.undetermined', 'Undetermined chats', '${o.undetermined}');
  }
  for (final p in efficiency?.processMetrics ?? const <ProcessMetric>[]) {
    final id =
        'process.${p.metric}${p.provider == null ? '' : '.${p.provider}'}';
    final label = p.metric.replaceAll('_', ' ');
    final v = p.value;
    add(
        id,
        label[0].toUpperCase() + label.substring(1),
        v == null
            ? 'N/A'
            : switch (p.metric) {
                'context_growth' || 'cost_tail' => '${v.toStringAsFixed(1)}×',
                'tokens_per_turn_vs_median' =>
                  '${v >= 0 ? '+' : '−'}${(v.abs() * 100).toStringAsFixed(0)}%',
                _ => _pct(v),
              });
  }
  for (final s in efficiency?.setups ?? const <SetupMetric>[]) {
    final pre =
        'setup.${s.provider}.${s.model}${s.effort == null ? '' : '.${s.effort}'}.${s.taskGroup}';
    add('$pre.sr', 'Success rate (${s.name}, ${s.taskGroup})',
        s.sr == null ? 'N/A' : _pct(s.sr!));
    add('$pre.cpst', 'Cost per success (${s.name}, ${s.taskGroup})',
        s.cpstMicro == null ? 'N/A' : _usd(s.cpstMicro!));
    add('$pre.n_tasks', 'Tasks (${s.name}, ${s.taskGroup})', '${s.tasks}');
    add('$pre.verdict', 'Verdict (${s.name}, ${s.taskGroup})', s.verdict);
  }
  for (final m in byModel(docs)) {
    final pre = 'usage.${m.value.provider}.${m.key}';
    final v = m.value;
    add('$pre.tokens', 'Tokens (${m.key})', '${v.tokens}');
    add('$pre.cost_micro', 'Cost (${m.key})',
        v.costKnown ? _usd(v.cost) : 'N/A');
    add('$pre.cache_rate', 'Cache hit rate (${m.key})',
        v.input == 0 ? 'N/A' : _pct(v.cached / v.input));
    add('$pre.thinking_share', 'Thinking share (${m.key})',
        v.output == 0 ? 'N/A' : _pct(v.thinking / v.output));
  }
  final dates = docs.map((d) => d.date).toList()..sort();
  final pricingVersions =
      docs.map((d) => d.pricingVersion).whereType<String>().toSet();
  return JudgeBrief(
      periodStart: since != null
          ? dayKey(since)
          : dates.isEmpty
              ? dayKey(today)
              : dates.first,
      periodEnd: dayKey(today),
      catalog: c,
      chats: t.chats,
      requests: t.requests,
      monthlyCostMicro: t.costKnown ? t.cost : 0,
      pricingVersion:
          pricingVersions.isEmpty ? 'unknown' : pricingVersions.join(','));
}

/// Error codes shared with the desktop and the mobile UI.
class JudgeException implements Exception {
  JudgeException(this.code);
  final String code;
  @override
  String toString() => 'JudgeException($code)';
}

String? _httpError(int status, String body) {
  if (status == 401 || status == 403 || body.contains('API_KEY_INVALID')) {
    return 'invalid_api_key';
  }
  if (status == 429) return 'rate_limited';
  if (status == 200) return null;
  if (status == 404 || body.contains('model')) return 'invalid_model';
  return 'provider_error';
}

/// Sends one structured-output request and returns the raw JSON text.
Future<String> callProvider(
    {required http.Client client,
    required String provider,
    required String model,
    required String apiKey,
    required String system,
    required String user,
    Duration timeout = const Duration(seconds: 150)}) async {
  final http.Response res;
  try {
    res = switch (provider) {
      'anthropic' => await client
          .post(Uri.parse('https://api.anthropic.com/v1/messages'),
              headers: {
                'x-api-key': apiKey,
                'anthropic-version': '2023-06-01',
                'content-type': 'application/json',
              },
              body: jsonEncode({
                'model': model,
                'max_tokens': 16000,
                'system': system,
                'messages': [
                  {'role': 'user', 'content': user}
                ],
                'output_config': {
                  'effort': 'medium',
                  'format': {'type': 'json_schema', 'schema': judgeSchema},
                },
              }))
          .timeout(timeout),
      'openai' => await client
          .post(Uri.parse('https://api.openai.com/v1/chat/completions'),
              headers: {
                'authorization': 'Bearer $apiKey',
                'content-type': 'application/json',
              },
              body: jsonEncode({
                'model': model,
                'messages': [
                  {'role': 'system', 'content': system},
                  {'role': 'user', 'content': user},
                ],
                'response_format': {
                  'type': 'json_schema',
                  'json_schema': {
                    'name': 'insights',
                    'strict': true,
                    'schema': judgeSchema
                  },
                },
              }))
          .timeout(timeout),
      _ => await client
          .post(
              Uri.parse(
                  'https://generativelanguage.googleapis.com/v1beta/models/${Uri.encodeComponent(model)}:generateContent'),
              headers: {
                'x-goog-api-key': apiKey,
                'content-type': 'application/json',
              },
              body: jsonEncode({
                'systemInstruction': {
                  'parts': [
                    {'text': system}
                  ]
                },
                'contents': [
                  {
                    'role': 'user',
                    'parts': [
                      {'text': user}
                    ]
                  }
                ],
                'generationConfig': {
                  'responseMimeType': 'application/json',
                  'responseJsonSchema': judgeSchema,
                },
              }))
          .timeout(timeout),
    };
  } on JudgeException {
    rethrow;
  } catch (_) {
    throw JudgeException('network');
  }
  final body = utf8.decode(res.bodyBytes);
  final error = _httpError(res.statusCode, body);
  if (error != null) throw JudgeException(error);
  final root = jsonDecode(body) as Map<String, dynamic>;
  switch (provider) {
    case 'anthropic':
      final stop = root['stop_reason'];
      if (stop == 'refusal') throw JudgeException('refused');
      if (stop == 'max_tokens') throw JudgeException('truncated');
      for (final b in (root['content'] as List? ?? const [])) {
        if (b is Map && b['type'] == 'text') return b['text'] as String;
      }
      throw JudgeException('provider_error');
    case 'openai':
      final choice = (root['choices'] as List?)?.firstOrNull as Map?;
      final message = choice?['message'] as Map?;
      if (message?['refusal'] != null) throw JudgeException('refused');
      if (choice?['finish_reason'] == 'length') {
        throw JudgeException('truncated');
      }
      final text = message?['content'];
      if (text is String) return text;
      throw JudgeException('provider_error');
    default:
      final cand = (root['candidates'] as List?)?.firstOrNull as Map?;
      final finish = cand?['finishReason'];
      if (finish == 'SAFETY') throw JudgeException('refused');
      if (finish == 'MAX_TOKENS') throw JudgeException('truncated');
      final parts = (cand?['content'] as Map?)?['parts'] as List?;
      final text = (parts?.firstOrNull as Map?)?['text'];
      if (text is String) return text;
      throw JudgeException('provider_error');
  }
}

int? _clampScore(Object? v) => v is num ? v.round().clamp(0, 100) : null;

/// Turns raw model output into an insights document, dropping anything that
/// cites an unknown metric (evidence values always come from the brief).
Map<String, dynamic> validateOutput(String text, JudgeBrief brief,
    {required String provider, required String model, required DateTime now}) {
  final Map<String, dynamic> out;
  try {
    out = jsonDecode(text) as Map<String, dynamic>;
  } catch (_) {
    throw JudgeException('provider_error');
  }
  final dims = <String, Map<String, dynamic>>{};
  for (final d in (out['dimensions'] as List? ?? const [])) {
    if (d is! Map || !judgeCategories.contains(d['id'])) continue;
    dims.putIfAbsent(
        d['id'] as String,
        () => {
              'id': d['id'],
              'score': _clampScore(d['score']),
              'comment': d['comment'] is String ? d['comment'] : '',
            });
  }
  final seen = <String>{};
  final insights = <Map<String, dynamic>>[];
  for (final i in (out['insights'] as List? ?? const [])) {
    if (i is! Map) continue;
    final evidence = [
      for (final e in (i['evidence'] as List? ?? const []))
        if (e is Map && brief.catalog.containsKey(e['metric']))
          {
            'metric': e['metric'],
            'label': brief.catalog[e['metric']]!.label,
            'value': brief.catalog[e['metric']]!.value,
          }
    ];
    final id = i['id'] is String && (i['id'] as String).isNotEmpty
        ? i['id'] as String
        : 'insight-${insights.length + 1}';
    if (evidence.isEmpty ||
        !judgeCategories.contains(i['category']) ||
        !_levels.contains(i['severity']) ||
        !_levels.contains(i['confidence']) ||
        !seen.add(id)) {
      continue;
    }
    final saving = i['estimated_saving_usd_per_month'];
    insights.add({
      'id': id,
      'title': i['title'] is String ? i['title'] : '',
      'severity': i['severity'],
      'category': i['category'],
      'provider': _tools.contains(i['provider']) ? i['provider'] : null,
      'evidence': evidence,
      'recommendation':
          i['recommendation'] is String ? i['recommendation'] : '',
      'estimated_impact':
          i['estimated_impact'] is String ? i['estimated_impact'] : null,
      'estimated_saving_micro_per_month': saving is num
          ? (saving * 1e6).round().clamp(0, brief.monthlyCostMicro)
          : null,
      'confidence': i['confidence'],
      'why': i['why'] is String ? (i['why'] as String).trim() : '',
      'steps': [
        for (final s in i['steps'] is List ? i['steps'] as List : const [])
          if (s is String && s.trim().isNotEmpty) s.trim()
      ].take(4).toList(),
    });
    if (insights.length == 5) break;
  }
  final grade = out['grade'];
  return {
    ..._base(brief, provider, model, now),
    'status': 'ok',
    'score': _clampScore(out['score']),
    'grade': const {'A', 'B', 'C', 'D'}.contains(grade) ? grade : null,
    'headline': out['headline'] is String ? out['headline'] : '',
    'dimensions': dims.values.toList(),
    'insights': insights,
    'error_code': null,
  };
}

Map<String, dynamic> _base(
        JudgeBrief brief, String provider, String model, DateTime now) =>
    {
      'schema_version': 1,
      'generated_at': '${now.toUtc().toIso8601String().split('.').first}Z',
      'period_start': brief.periodStart,
      'period_end': brief.periodEnd,
      'provider': provider,
      'model': model,
      'source': 'phone',
      'pricing_version': brief.pricingVersion,
      'score': null,
      'grade': null,
    };

/// SRS FR-RECO-001 data rule: needs ≥ 3 days of data and ≥ 5 chats.
bool briefIsSufficient(JudgeBrief brief, List<DailyDoc> all, DateTime now) =>
    filterLastDays(all, 30, now).length >= 3 && brief.chats >= 5;

/// Full run: brief → provider → validated document. Insufficient data returns
/// an `insufficient_data` document without calling the provider.
Future<Map<String, dynamic>> runJudge(
    {required http.Client client,
    required List<DailyDoc> daily,
    required EfficiencyDoc? efficiency,
    required String provider,
    required String model,
    required String apiKey,
    required String language,
    DateTime? now,
    DateTime? since}) async {
  final at = now ?? DateTime.now();
  final brief = buildBrief(daily, efficiency, now: at, since: since);
  if (since == null && !briefIsSufficient(brief, daily, at)) {
    return {
      ..._base(brief, provider, model, at),
      'status': 'insufficient_data',
      'headline': '',
      'dimensions': const [],
      'insights': const [],
      'error_code': null,
    };
  }
  // Retry malformed output up to 3 times (SRS FR-RECO-001).
  JudgeException? last;
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      final text = await callProvider(
          client: client,
          provider: provider,
          model: model,
          apiKey: apiKey,
          system: judgeSystemPrompt(language),
          user: brief.toJson());
      return validateOutput(text, brief,
          provider: provider, model: model, now: at);
    } on JudgeException catch (e) {
      last = e;
      if (e.code != 'provider_error') rethrow;
    }
  }
  throw last!;
}

/// Tiny request used by "Test connection": checks key and model only.
Future<void> testProvider(
    {required http.Client client,
    required String provider,
    required String model,
    required String apiKey}) async {
  final brief = JudgeBrief(
      periodStart: '2026-01-01',
      periodEnd: '2026-01-30',
      catalog: {'usage.chats': const BriefMetric('Chats', '12')},
      chats: 12,
      requests: 40,
      monthlyCostMicro: 1000000);
  final text = await callProvider(
      client: client,
      provider: provider,
      model: model,
      apiKey: apiKey,
      system: judgeSystemPrompt('English'),
      user: brief.toJson(),
      timeout: const Duration(seconds: 60));
  validateOutput(text, brief,
      provider: provider, model: model, now: DateTime.now());
}
