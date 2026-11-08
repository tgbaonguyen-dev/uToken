part of 'figma_mock_repository.dart';

// shortcut: bindings follow these Figma exports; update when re-exporting.
FigmaMockScreen _extraMockScreen(
    FigmaMockScreen original,
    String id,
    Map<String, dynamic> fixtures,
    Map<String, dynamic> settings,
    Map<String, dynamic>? export) {
  final layers =
      original.layers.map((l) => Map<String, dynamic>.from(l)).toList();
  void text(int i, Object value) => layers[i]['v'] = value.toString();
  String money(num n, [int digits = 2]) => '\$${n.toStringAsFixed(digits)}';
  String rate(num n) => money(n, (n * 100).roundToDouble() == n * 100 ? 2 : 3);
  if (id != 'O03') text(1, '\u2039');
  switch (id) {
    case 'O01':
      final rows = (export!['records'] as List).cast<Map>();
      final total = rows.fold<num>(0, (sum, r) => sum + (r['tokens'] as num));
      final cents = rows.fold<int>(0,
          (sum, r) => sum + ((r['estimated_cost_usd'] as num) * 100).round());
      text(6, '\u21e9');
      text(8,
          '${rows.length} daily records \u00b7 ${fixtures['export']['label']}');
      text(
          10,
          settings['numberFormat'] == 'Full'
              ? NumberFormat.decimalPattern('en_US').format(total)
              : '${(total / 1000000).toStringAsFixed(2)}M');
      layers[10]['fit'] = 'scaleDown';
      text(12, money(cents / 100));
      text(14, rows.map((r) => r['date']).toSet().length);
      text(16, 'Mock preview only. No file is saved.');
      for (var i = 0; i < 3; i++) {
        final column = ['gemini_tokens', 'codex_tokens', 'claude_tokens'][i];
        final amount = rows.fold<num>(0, (sum, r) => sum + (r[column] as num));
        text([24, 26, 28][i], '${(amount / total * 100).toStringAsFixed(1)}%');
      }
    case 'O02':
      final alert = fixtures['alert'] as Map;
      final limit = settings['monthlyLimit'] as num;
      final fraction = alert['usageFraction'] as num;
      final spent = (limit * fraction * 100).round() / 100;
      text(3, alert['subtitle']);
      text(7, '${(fraction * 100).round()}% used');
      text(8, '${money(spent)} of ${money(limit)}');
      layers[10]['w'] = 318 * fraction.clamp(0, 1);
      text(11, '${money(limit - spent)} remaining');
      text(21, alert['contributor']);
      text(22, '+${money(alert['weeklyIncrease'] as num)} this week');
    case 'M14':
      final catalog = fixtures['catalog'] as Map;
      text(7, 'Sample catalog \u00b7 ${catalog['updatedLabel']}');
      final models = (catalog['models'] as List).cast<Map>();
      for (var i = 0; i < models.length; i++) {
        final model = models[i];
        text([10, 21, 32][i], model['provider']);
        text([11, 22, 33][i], model['name']);
        text([14, 25, 36][i], rate(model['input'] as num));
        text([16, 27, 38][i], rate(model['cached'] as num));
        text([18, 29, 40][i], rate(model['output'] as num));
        text(
            [45, 47, 49][i],
            model['cacheWrite'] == null
                ? '\u2014'
                : rate(model['cacheWrite'] as num));
      }
    case 'O03':
      final example = fixtures['costExample'] as Map;
      final model = fixtures['catalog']['models'][example['modelIndex']] as Map;
      var total = 0.0;
      for (var i = 0; i < 3; i++) {
        final count =
            example[['inputTokens', 'cachedTokens', 'outputTokens'][i]] as num;
        final price = model[['input', 'cached', 'output'][i]] as num;
        final cost = count / 1000000 * price;
        total += cost;
        text([12, 15, 18][i],
            '${NumberFormat.compact(locale: 'en_US').format(count)} \u00d7 ${rate(price)} / MTok');
        text([13, 16, 19][i], money(cost, 4));
      }
      text(7, money(total, 4));
      text(22, money(total, 4));
      text(8, 'Mock example \u00b7 ${model['name']} \u00b7 ${example['tier']}');
      text(
          24, 'Calculated from the sample price catalog. Not a provider bill.');
    case 'M15':
      final ai = fixtures['ai'] as Map;
      final providers = (ai['providers'] as List).cast<Map>();
      final selected =
          providers.indexWhere((p) => p['name'] == settings['aiProvider']);
      text(11, '\u2713');
      layers[11]['y'] = 210 + selected * 56;
      text(21, settings['aiModel']);
      text(
          25,
          settings['aiKeyPresent'] == true
              ? '${providers[selected]['keyMask']} \u00b7 demo only'
              : 'No demo key');
      text(29, settings['aiCheckedAt']);
      text(30, settings['aiConnection']);
      text(31, ai['note']);
      layers[31]['h'] = 60;
  }
  return FigmaMockScreen(
      nodeId: original.nodeId,
      name: original.name,
      width: original.width,
      height: original.height,
      layers: layers);
}
