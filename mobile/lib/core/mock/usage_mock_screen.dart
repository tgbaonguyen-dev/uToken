part of 'figma_mock_repository.dart';

/// Binds business fixtures to the existing light/dark Figma layout.
/// shortcut: layer indices follow these exports; update bindings when re-exporting.
class _UsageMockScreen {
  _UsageMockScreen(this.original, this.fixtures, this.tokens, this.period,
      {this.fullNumbers = false, this.selectedDay})
      : layers =
            original.layers.map((l) => Map<String, dynamic>.from(l)).toList() {
    for (var index = 0; index < original.layers.length; index++) {
      final layer = original.layers[index];
      if (layer['t'] != 't') continue;
      final sourceText = layer['v']?.toString() ?? '';
      final occurrence = original.layers
          .take(index)
          .where((candidate) =>
              candidate['t'] == 't' && candidate['v']?.toString() == sourceText)
          .length;
      _textBindings[index] = FigmaLayerBindings.textIndex(
        layers,
        sourceText,
        occurrence: occurrence,
      );
    }
  }

  final Map<int, int> _textBindings = {};
  final FigmaMockScreen original;
  final Map<String, dynamic> fixtures;
  final Map tokens;
  final String period;
  final bool fullNumbers;
  final String? selectedDay;
  final List<Map<String, dynamic>> layers;

  Map get data => fixtures['periods'][period] as Map;
  String money(num n) => '\$${n.toStringAsFixed(2)}';
  String compact(num n) => fullNumbers
      ? NumberFormat.decimalPattern('en_US').format(n)
      : n >= 1000000
          ? '${(n / 1000000).toStringAsFixed(2)}M'
          : n >= 1000
              ? '${(n / 1000).toStringAsFixed(1)}K'
              : '$n';

  void text(int sourceIndex, Object value) {
    final targetIndex = _textBindings[sourceIndex];
    if (targetIndex == null) {
      throw StateError(
          'Missing semantic text binding for source layer $sourceIndex');
    }
    layers[targetIndex]['v'] = value.toString();
    if (fullNumbers && RegExp(r'^[\d,]+$').hasMatch(value.toString())) {
      layers[targetIndex]['fit'] = 'scaleDown';
    }
  }

  void selectOptions(
    List<String> options,
    int selected,
    int originalSelected,
  ) {
    final textIndices = [
      for (final option in options)
        FigmaLayerBindings.textIndex(original.layers, option),
    ];
    final backgrounds = [
      for (final index in textIndices)
        FigmaLayerBindings.backgroundForText(layers, index),
    ];
    final fallback = originalSelected == 0 ? 1 : 0;
    final activeBackground = layers[backgrounds[originalSelected]]['c'];
    final inactiveBackground = layers[backgrounds[fallback]]['c'];
    final activeText = layers[textIndices[originalSelected]]['c'];
    final inactiveText = layers[textIndices[fallback]]['c'];
    final activeWeight = layers[textIndices[originalSelected]]['fw'];
    final inactiveWeight = layers[textIndices[fallback]]['fw'];
    for (var i = 0; i < options.length; i++) {
      layers[backgrounds[i]]['c'] =
          i == selected ? activeBackground : inactiveBackground;
      layers[textIndices[i]]['c'] = i == selected ? activeText : inactiveText;
      layers[textIndices[i]]['fw'] =
          i == selected ? activeWeight : inactiveWeight;
    }
  }

  List<Map<String, dynamic>> get models =>
      MockUsageAggregator.rankedModels(data);

  String share(Map row) =>
      '${((row['tokens'] as num) / (tokens['totalTokens'] as num) * 100).toStringAsFixed(1)}%';

  FigmaMockScreen build(
      String id, String size, String grouping, String sortBy, bool ascending) {
    switch (id) {
      case 'M04B':
        details();
      case 'M05':
        analytics();
      case 'M05B':
        efficiency();
      case 'M05C':
        comparison(size);
      case 'M06':
        daily(grouping, sortBy, ascending);
      case 'M07':
        suggestions();
    }
    return FigmaMockScreen(
        nodeId: original.nodeId,
        name: original.name,
        width: original.width,
        height: original.height,
        layers: layers);
  }

  void modelRows(List<int> names, List<int> totals, List<int> shares) {
    final rows = models;
    for (var i = 0; i < rows.length; i++) {
      text(names[i], rows[i]['name']);
      text(
          totals[i],
          fullNumbers
              ? compact(rows[i]['tokens'] as num)
              : '${((rows[i]['tokens'] as num) / 1000000).toStringAsFixed(2)}M');
      text(shares[i], share(rows[i]));
    }
  }

  List<int> _activityLevelsFromRecords(List records) =>
      MockUsageAggregator.activityLevels(records);

  void details() {
    text(4, period == 'Month' ? 'Top models' : 'Top models / $period');
    // Keep row icons tied to the model identity when the ranking changes.
    final icons = {
      for (var i = 0; i < 4; i++)
        original.layers[[7, 12, 17, 22][i]]['v']: original.layers.firstWhere(
            (l) => l['t'] == 'a' && l['y'] == [157, 211, 265, 319][i])['id']
    };
    modelRows([7, 12, 17, 22], [8, 13, 18, 23], [9, 14, 19, 24]);
    for (var i = 0; i < 4; i++) {
      layers.firstWhere(
              (l) => l['t'] == 'a' && l['y'] == [157, 211, 265, 319][i])['id'] =
          icons[models[i]['name']];
    }

    // Real daily activity records take precedence over the static preview levels.
    // Expected record shape: { date: ..., tokens: ... } (or totalTokens).
    final activity = fixtures['activity'];
    final levels = activity is List
        ? _activityLevelsFromRecords(activity)
        : (fixtures['activityLevels'] as List).cast<int>();
    text(26,
        '${activity is List ? activity.length : fixtures['activityDays']} days');
    final palette = [for (var i = 171; i <= 175; i++) layers[i]['c']];
    const heatmapCells = 119;
    final visibleLevels = levels.length > heatmapCells
        ? levels.sublist(levels.length - heatmapCells)
        : levels;
    final leadingEmptyCells = heatmapCells - visibleLevels.length;
    for (var i = 0; i < heatmapCells; i++) {
      final level =
          i < leadingEmptyCells ? 0 : visibleLevels[i - leadingEmptyCells];
      layers[27 + i]['c'] = palette[level.clamp(0, palette.length - 1).toInt()];
    }
    final days = fixtures['daily'] as List;
    for (var i = 0; i < 3; i++) {
      final row = days[i] as Map;
      text(178 + 4 * i, row['label']);
      text(179 + 4 * i, '${row['chats']} chats');
      text(180 + 4 * i, compact(row['tokens'] as num));
    }
  }

  void analytics() {
    selectOptions(['Day', 'Week', 'Month', 'Total'],
        ['Day', 'Week', 'Month', 'Total'].indexOf(period), 2);
    text(13, compact(tokens['totalTokens'] as num));
    text(14, money(tokens['estimatedCost'] as num));
    final input = data['inputPercent'] as num;
    text(18, 'Input ${input.toStringAsFixed(1)}%');
    text(19, 'Output ${(100 - input).toStringAsFixed(1)}%');
    final width = 318 * input / 100;
    layers[16]['w'] = width;
    layers[17].addAll({'x': 36 + width, 'w': 318 - width});
    final icons = {
      for (var i = 0; i < 4; i++)
        original.layers[[24, 28, 32, 36][i]]['v']: layers[56 + i]['id']
    };
    modelRows([24, 28, 32, 36], [25, 29, 33, 37], [26, 30, 34, 38]);
    for (var i = 0; i < 4; i++) {
      layers[56 + i]['id'] = icons[models[i]['name']];
    }
    text(40, data['costLabel']);
    text(53, money(tokens['estimatedCost'] as num));
    text(54, '+${data['costChangePercent']}%');
    text(78, '${data['efficiency']['successRate']}% success');
    final values = (data['costBars'] as List).whereType<num>().toList();
    final maxValue = values.fold<num>(
        0, (current, value) => value > current ? value : current);
    final scaleMax = maxValue <= 0 ? 1 : maxValue;
    final template = layers[41];
    final emphasisColor = layers[50]['c'];
    final bars = [
      for (var i = 0; i < values.length; i++)
        {
          ...template,
          'x': 145 + i * 187 / (values.length > 1 ? values.length - 1 : 1),
          'w': (197 / (values.isEmpty ? 1 : values.length) - 2).clamp(1, 10),
          'c': i >= values.length - (data['costEmphasisBars'] as int)
              ? emphasisColor
              : template['c'],
          'h': values[i] / scaleMax * 70,
          'y': 676 - values[i] / scaleMax * 70,
        }
    ];
    layers.replaceRange(41, 53, bars);
  }

  void efficiency() {
    final e = data['efficiency'] as Map;
    text(3, e['periodLabel']);
    text(7, money(e['costPerSuccess'] as num));
    text(9,
        '${e['changePercent']}% vs ${period == 'Month' ? 'last month' : 'prior period'}');
    layers[9].addAll({'x': 228, 'w': 126, 'al': 'RIGHT'});
    for (final binding in {
      11: 'successRate',
      13: 'firstPass',
      15: 'reworkCost',
      21: 'cacheHitRate',
      33: 'thinkingShare',
      39: 'retryRate'
    }.entries) {
      text(binding.key, '${e[binding.value]}%');
    }
    text(27, '${e['contextGrowth']}\u00d7');
    final best = fixtures['comparison']['Medium']['models'][0]['name'];
    text(44, 'Medium tasks: $best gives most success per \$');
  }

  void comparison(String size) {
    final c = fixtures['comparison'][size] as Map;
    final ranked = c['models'] as List;
    final best = ranked.first as Map;
    selectOptions(['Small', 'Medium', 'Large'],
        ['Small', 'Medium', 'Large'].indexOf(size), 1);
    text(11, c['description']);
    // This Figma label needs more room for the large-task range.
    layers[11].addAll({'x': 224, 'w': 146});
    text(13, 'BEST FOR ${size.toUpperCase()} TASKS');
    layers[13]['w'] = 220;
    text(15, best['name']);
    text(16, '${best['successRate']}%');
    text(18, money(best['costPerSuccess'] as num));
    final cheaper =
        (1 - (best['costPerSuccess'] as num) / (c['medianCost'] as num)) * 100;
    text(20, '${cheaper.round()}%');
    final colors = {
      for (var i = 0; i < 3; i++)
        original.layers[[28, 39, 48][i]]['v']: original.layers[[27, 38, 47][i]]
            ['c']
    };
    layers[14]['c'] = colors[best['name']];
    for (var i = 0; i < 3; i++) {
      final row = ranked[i] as Map;
      text([28, 39, 48][i], row['name']);
      layers[[28, 39, 48][i]]['w'] = 150;
      text([31, 40, 49][i], (row['efficiencyIndex'] as num).toStringAsFixed(2));
      text([34, 43, 52][i], '${row['successRate']}% success');
      text([35, 44, 53][i], '${money(row['costPerSuccess'] as num)} / success');
      layers[[33, 42, 51][i]].addAll({
        'w': 96 * (row['successRate'] as num) / 100,
        'c': colors[row['name']]
      });
      layers[[27, 38, 47][i]]['c'] = colors[row['name']];
    }
    text(54, c['reworkNote']);
    final unranked = c['unranked'] as Map;
    text(58, unranked['name']);
    text(62,
        '${unranked['chats']} of ${unranked['requiredChats']} chats needed to rank');
    layers[61]['w'] =
        96 * (unranked['chats'] as num) / (unranked['requiredChats'] as num);
  }

  void daily(String grouping, String sortBy, bool ascending) {
    final project = grouping == 'Project';
    final rows = (fixtures[project ? 'projects' : 'daily'] as List)
        .map((r) => Map.from(r as Map))
        .toList();
    final key = sortBy == 'date' ? (project ? 'label' : 'date') : sortBy;
    final sortedRows = MockUsageAggregator.sortedRows(
      rows,
      key: key,
      ascending: ascending,
    );
    selectOptions(['Daily', 'Project'], project ? 1 : 0, 0);
    text(2, project ? 'Project usage' : 'Daily usage');
    for (final header in {
      9: project ? 'Project' : 'Date',
      10: 'Total',
      11: 'Chats'
    }.entries) {
      final selected =
          {9: 'date', 10: 'tokens', 11: 'chats'}[header.key] == sortBy;
      text(header.key,
          '${header.value}${selected ? (ascending ? ' \u2191' : ' \u2193') : ''}');
    }
    for (var i = 0; i < sortedRows.length; i++) {
      text(13 + i * 4, sortedRows[i]['label']);
      layers[13 + i * 4]['w'] = 130;
      text(14 + i * 4, compact(sortedRows[i]['tokens'] as num));
      text(15 + i * 4, sortedRows[i]['chats']);
      if (!project && sortedRows[i]['date'] == selectedDay) {
        for (final index in [13 + i * 4, 14 + i * 4, 15 + i * 4]) {
          layers[index]['c'] = '#ff38d39f';
        }
      }
    }
  }

  void suggestions() {
    final s = data['suggestions'] as Map;
    text(5, money((s['contextSavings'] as num) + (s['cacheSavings'] as num)));
    text(6, s['savingsLabel']);
    text(7, '${s['count']} suggestions');
    text(13,
        '${s['affectedChats']} chats \u00b7 ${s['inputReduction']}% less input');
    text(17,
        '${s['cachedSessionsLabel']} \u00b7 save ${money(s['cacheSavings'] as num)}');
  }
}
