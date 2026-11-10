import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'presentation/mock_usage_aggregator.dart';
import 'presentation/figma_layer_bindings.dart';

part 'usage_mock_screen.dart';
part 'settings_mock_screen.dart';
part 'extra_mock_screen.dart';

/// Read-only presentation fixtures extracted from the original Figma file.
/// Text, numbers, colors, sizes and positions are never hard-coded in widgets.
class FigmaMockRepository {
  FigmaMockRepository._();

  static const Map<String, int> _fileIndex = {
    'M01': 1,
    'M02': 1,
    'M03': 2,
    'M04': 2,
    'M04B': 3,
    'M05': 3,
    'M05B': 4,
    'M05C': 4,
    'M06': 5,
    'M07': 5,
    'M09': 6,
    'M10': 6,
    'M11': 7,
    'M12': 7,
    'M13': 8,
    'O01': 8,
    'O02': 9,
    'M14': 9,
    'O03': 10,
    'M15': 10,
    'S01': 11,
    'S02': 11,
    'S03': 12,
    'S04': 12,
  };

  static Iterable<String> get screenIds => _fileIndex.keys;

  static final Map<String, Future<Map<String, dynamic>>> _cache = {};

  static Future<Map<String, dynamic>> _loadFile(String assetPath) =>
      _cache.putIfAbsent(assetPath, () async {
        final raw = await rootBundle.loadString(assetPath);
        return jsonDecode(raw) as Map<String, dynamic>;
      });

  static String _assetPath(String mode, int index) {
    final paddedIndex = index.toString().padLeft(2, '0');
    return 'lib/core/mock/data/figma_$mode' '_$paddedIndex.json';
  }

  static Future<FigmaMockScreen> screen(
    String screenId,
    Brightness brightness,
  ) async {
    if (screenId == 'M08') {
      final data = await _loadFile(_assetPath('dark', 13));
      return FigmaMockScreen.fromJson(
          Map<String, dynamic>.from(data['M08'] as Map));
    }
    final index = _fileIndex[screenId];
    if (index == null) {
      throw ArgumentError.value(screenId, 'screenId', 'Unknown Figma screen');
    }
    final mode = brightness == Brightness.dark ? 'dark' : 'light';
    Map<String, dynamic> screens;
    try {
      screens = await _loadFile(_assetPath(mode, index));
    } on FlutterError {
      screens = await _loadFile(_assetPath('light', index));
    }
    final row = screens[screenId];
    if (row is Map) {
      return FigmaMockScreen.fromJson(Map<String, dynamic>.from(row));
    }
    final light = await _loadFile(_assetPath('light', index));
    final fallback = light[screenId];
    if (fallback is! Map) {
      throw StateError('Missing Figma frame $screenId');
    }
    return FigmaMockScreen.fromJson(Map<String, dynamic>.from(fallback));
  }

  /// Interactions for the UI demo live separately from the Figma exports.
  static Future<Map<String, dynamic>> demoInteractions() => _loadFile(
        'lib/core/mock/data/figma_demo_interactions.json',
      );

  static Future<FigmaMockScreen> insightScreen({bool reviewed = false}) async {
    final original = await screen('M08', Brightness.dark);
    final source =
        await _loadFile('assets/data/mocks/insight_detail_active.json');
    final usage = await _loadFile('lib/core/mock/data/usage_explorer.json');
    final amount =
        usage['periods']['Month']['suggestions']['contextSavings'] as num;
    final summary = source['impact_summary'] as Map;
    final data = {
      ...source,
      'impact_summary': {
        ...summary,
        'cost': (summary['cost_template'] as String)
            .replaceAll('{amount}', amount.toStringAsFixed(2)),
      }
    };
    final layers = original.layers.map((layer) {
      final result = Map<String, dynamic>.from(layer);
      final binding = layer['bind'] as String?;
      if (binding != null) {
        dynamic value = data;
        for (final part in binding.split('.')) {
          value = value is List ? value[int.parse(part)] : value[part];
        }
        if (reviewed && binding == 'status') value = data['reviewed_status'];
        if (reviewed && binding == 'action_text') {
          value = data['reviewed_action_text'];
        }
        result['v'] = value.toString();
      }
      return result;
    }).toList();
    return FigmaMockScreen(
        nodeId: original.nodeId,
        name: original.name,
        width: original.width,
        height: original.height,
        layers: layers);
  }

  static final settingsRevision = ValueNotifier<int>(0);
  static Map<String, dynamic>? _settings;

  static Future<Map<String, dynamic>> settingsData() async {
    final file = await _loadFile('lib/core/mock/data/settings_session.json');
    _settings ??= Map<String, dynamic>.from(file['defaults'] as Map);
    return Map<String, dynamic>.from(_settings!);
  }

  static Future<List<String>> settingsOptions(String key) async {
    final file = await _loadFile('lib/core/mock/data/settings_session.json');
    return (file['options'][key] as List).cast<String>();
  }

  /// Session-only preferences: never writes files or calls a backend.
  static Future<void> updateSettings(Map<String, dynamic> changes) async {
    final current = await settingsData();
    for (final entry in changes.entries) {
      final value = entry.value;
      if (const ['language', 'numberFormat', 'syncInterval']
          .contains(entry.key)) {
        if (!(await settingsOptions(entry.key)).contains(value)) {
          throw ArgumentError.value(value, entry.key);
        }
      } else if (entry.key == 'aiProvider' || entry.key == 'aiModel') {
        final ai = (await extraData())['ai'] as Map;
        final providers = (ai['providers'] as List).cast<Map>();
        if (entry.key == 'aiProvider') {
          if (!providers.any((p) => p['name'] == value)) {
            throw ArgumentError.value(value, entry.key);
          }
        } else {
          final provider = changes['aiProvider'] ?? current['aiProvider'];
          final options = providers
              .firstWhere((p) => p['name'] == provider)['models'] as List;
          if (!options.contains(value)) {
            throw ArgumentError.value(value, entry.key);
          }
        }
      } else if (entry.key == 'aiConnection') {
        if (!const ['Connected', 'Not checked', 'Missing key']
            .contains(value)) {
          throw ArgumentError.value(value, entry.key);
        }
      } else if (entry.key == 'aiCheckedAt') {
        if (!const ['Not checked', 'Just now (mock)'].contains(value)) {
          throw ArgumentError.value(value, entry.key);
        }
      } else if (entry.key == 'monthlyLimit') {
        if (value is! num || !value.isFinite || value < 1 || value > 100000) {
          throw ArgumentError.value(value, entry.key);
        }
      } else if (const [
        'alert90',
        'alert100',
        'backgroundSync',
        'diagnostics',
        'connected',
        'aiKeyPresent'
      ].contains(entry.key)) {
        if (value is! bool) throw ArgumentError.value(value, entry.key);
      } else if (entry.key == 'lastSync') {
        if (value != 'Just now') throw ArgumentError.value(value, entry.key);
      } else {
        throw ArgumentError.value(entry.key, 'setting');
      }
    }
    _settings = {...current, ...changes};
    settingsRevision.value++;
  }

  static const extraScreenIds = {'O01', 'O02', 'O03', 'M14', 'M15'};

  static const syncScreenIds = {'S01', 'S02', 'S03', 'S04'};

  static Future<FigmaMockScreen> syncScreen(
      String id, Brightness brightness) async {
    if (!syncScreenIds.contains(id)) throw ArgumentError.value(id, 'id');
    final original = await screen(id, brightness);
    final data = await _loadFile('lib/core/mock/data/sync_preview.json');
    final layers =
        original.layers.map((l) => Map<String, dynamic>.from(l)).toList();
    if (id == 'S02') {
      final providers = data['providers'] as List;
      const providerNameTemplates = ['Gemini', 'Codex', 'Claude'];
      const providerStatusTemplates = ['Ready', 'Ready', 'Ready'];
      for (var i = 0; i < providers.length; i++) {
        FigmaLayerBindings.setText(
          layers,
          providerNameTemplates[i],
          providers[i]['name'],
        );
        FigmaLayerBindings.setText(
          layers,
          providerStatusTemplates[i],
          providers[i]['status'],
          occurrence: i,
        );
      }
    } else if (id == 'S03') {
      final progress = (data['progress'] as num).toDouble();
      FigmaLayerBindings.setText(
        layers,
        '64%',
        '${(progress * 100).round()}%',
      );
      final progressIndicator = FigmaLayerBindings.layerAt(
        layers,
        type: 'e',
        x: 143,
        y: 119,
        width: 104,
        height: 104,
        occurrence: 1,
      );
      layers[progressIndicator].addAll({'t': 'p', 'progress': progress});
      final progressTrack = FigmaLayerBindings.rectangleAt(
        layers,
        x: 60,
        y: 670,
        width: 270,
      );
      layers[progressTrack]['w'] = 270;
      final progressFill = FigmaLayerBindings.rectangleAt(
        layers,
        x: 60,
        y: 670,
        width: 173,
      );
      layers[progressFill]['w'] = 270 * progress;
    } else if (id == 'S04') {
      FigmaLayerBindings.setText(
        layers,
        'Today, 10:42',
        data['lastSuccessfulSync'],
      );
      FigmaLayerBindings.setText(
        layers,
        '128 events',
        '${data['queuedEvents']} events',
      );
    }
    // Exported horizontal SVG strokes have zero layout height.
    for (final layer in layers) {
      if (layer['t'] == 'a' && layer['h'] == 0) layer['h'] = 1;
    }
    return FigmaMockScreen(
        nodeId: original.nodeId,
        name: original.name,
        width: original.width,
        height: original.height,
        layers: layers);
  }

  static Future<Map<String, dynamic>> extraData() =>
      _loadFile('lib/core/mock/data/extra_screens.json');

  static Future<Map<String, dynamic>> exportData() async {
    final usage = await _loadFile('lib/core/mock/data/usage_explorer.json');
    final tokens = await _loadFile('lib/core/mock/data/tokens_periods.json');
    final records = MockUsageAggregator.exportRecords(
      usage['daily'] as List,
      tokens['Month'] as Map,
    );
    return {'sample': true, 'records': records};
  }

  static Future<String> exportPreview(String format) async {
    final data = await exportData();
    if (format == 'JSON') {
      return const JsonEncoder.withIndent('  ').convert(data);
    }
    if (format != 'CSV') throw ArgumentError.value(format, 'format');
    final columns =
        ((await extraData())['export']['columns'] as List).cast<String>();
    final rows = data['records'] as List;
    return [
      columns.join(','),
      for (final row in rows)
        columns.map((column) => row[column].toString()).join(',')
    ].join('\n');
  }

  static Future<void> selectAiProvider(String provider) async {
    final providers =
        ((await extraData())['ai']['providers'] as List).cast<Map>();
    final matches = providers.where((p) => p['name'] == provider);
    if (matches.isEmpty) throw ArgumentError.value(provider, 'provider');
    await updateSettings({
      'aiProvider': provider,
      'aiModel': matches.first['models'][0],
      'aiKeyPresent': false,
      'aiConnection': 'Not checked',
      'aiCheckedAt': 'Not checked'
    });
  }

  static Future<void> testAiConnection() async {
    final data = await settingsData();
    await updateSettings({
      'aiConnection':
          data['aiKeyPresent'] == true ? 'Connected' : 'Missing key',
      'aiCheckedAt': 'Just now (mock)'
    });
  }

  static Future<FigmaMockScreen> extraScreen(
      String id, Brightness brightness) async {
    if (!extraScreenIds.contains(id)) throw ArgumentError.value(id, 'id');
    return _extraMockScreen(await screen(id, brightness), id, await extraData(),
        await settingsData(), id == 'O01' ? await exportData() : null);
  }

  static Future<FigmaMockScreen> settingsScreen(
      String id, Brightness brightness,
      {Map<String, dynamic>? budgetDraft,
      String? accountName,
      String? accountEmail}) async {
    if (!const ['M09', 'M10', 'M11', 'M12', 'M13'].contains(id)) {
      throw ArgumentError.value(id, 'id');
    }
    final preferences = {...await settingsData(), ...?budgetDraft};
    if (accountName != null) preferences['accountName'] = accountName;
    if (accountEmail != null) preferences['accountEmail'] = accountEmail;
    final periods = await _loadFile('lib/core/mock/data/tokens_periods.json');
    return _settingsMockScreen(
        await screen(id, brightness), id, preferences, periods['Month'] as Map);
  }

  static const explorerScreenIds = {
    'M04B',
    'M05',
    'M05B',
    'M05C',
    'M06',
    'M07',
  };

  static Future<FigmaMockScreen> usageScreen(
    String screenId,
    Brightness brightness, {
    String period = 'Month',
    String taskSize = 'Medium',
    String grouping = 'Daily',
    String sortBy = 'date',
    bool ascending = false,
    String? selectedDay,
  }) async {
    if (!explorerScreenIds.contains(screenId)) {
      throw ArgumentError.value(screenId, 'screenId');
    }
    final fixtures = await _loadFile('lib/core/mock/data/usage_explorer.json');
    final tokens = await _loadFile('lib/core/mock/data/tokens_periods.json');
    if (tokens[period] is! Map) throw ArgumentError.value(period, 'period');
    if (fixtures['comparison'][taskSize] is! Map) {
      throw ArgumentError.value(taskSize, 'taskSize');
    }
    if (!const ['Daily', 'Project'].contains(grouping)) {
      throw ArgumentError.value(grouping, 'grouping');
    }
    if (!const ['date', 'tokens', 'chats'].contains(sortBy)) {
      throw ArgumentError.value(sortBy, 'sortBy');
    }
    return _UsageMockScreen(await screen(screenId, brightness), fixtures,
            tokens[period] as Map, period,
            fullNumbers: (await settingsData())['numberFormat'] == 'Full',
            selectedDay: selectedDay)
        .build(screenId, taskSize, grouping, sortBy, ascending);
  }

  /// Business fixtures stay separate from the exported design layers.
  static Future<FigmaMockScreen> tokensScreen(
    Brightness brightness, {
    String period = 'Month',
  }) async {
    final fixtures = await _loadFile(
      'lib/core/mock/data/tokens_periods.json',
    );
    final data = fixtures[period];
    if (data is! Map) throw ArgumentError.value(period, 'period');
    final original = await screen('M04', brightness);
    final layers =
        original.layers.map((l) => Map<String, dynamic>.from(l)).toList();
    final fullNumbers = (await settingsData())['numberFormat'] == 'Full';
    final compact = fullNumbers
        ? NumberFormat.decimalPattern('en_US')
        : NumberFormat.compact(locale: 'en_US');
    if (fullNumbers) {
      for (final source in ['2.0M', '6.8M', '244K', '33.4K']) {
        layers[FigmaLayerBindings.textIndex(layers, source)]['sz'] = 10;
      }
    }
    final periods = ['Day', 'Week', 'Month', 'Total'];
    final labels = {
      for (final label in periods)
        label: FigmaLayerBindings.textIndex(layers, label),
    };
    final active = layers[labels['Month']!]['c'];
    final inactive = layers[labels['Day']!]['c'];
    final selectedLabel = labels[period];
    if (selectedLabel == null) throw ArgumentError.value(period, 'period');
    final selectedX = (layers[selectedLabel]['x'] as num).toDouble();
    final selectedWidth = (layers[selectedLabel]['w'] as num).toDouble();
    final selector = FigmaLayerBindings.rectangleAt(
      layers,
      x: 197,
      y: 118,
    );
    layers[selector]['x'] = selectedX;
    layers[selector]['w'] = selectedWidth;
    for (final label in periods) {
      layers[labels[label]!]['c'] = label == period ? active : inactive;
    }
    int textIndex(String source) =>
        FigmaLayerBindings.textIndex(layers, source);
    void text(String source, String value) =>
        layers[textIndex(source)]['v'] = value;
    text('6,830,736',
        NumberFormat.decimalPattern('en_US').format(data['totalTokens']));
    text('\$42.18 estimated',
        '\$${(data['estimatedCost'] as num).toStringAsFixed(2)} estimated');
    String summary(num value) => !fullNumbers && value >= 1000000
        ? '${(value / 1000000).toStringAsFixed(1)}M'
        : compact.format(value);
    text('2.0M', summary(data['sevenDayTokens'] as num));
    text('6.8M', summary(data['thirtyDayTokens'] as num));
    text('244K', compact.format(data['dailyAverage']));
    text('33.4K', compact.format(data['cachedTokens']));
    var x = 40.0;
    for (var i = 0; i < 3; i++) {
      final share = (data['shares'][i] as num).toDouble();
      layers[15 + i].addAll({'x': x, 'w': 304 * share / 100});
      x += 304 * share / 100;
      const shareLabels = ['62.4%', '28.8%', '8.8%'];
      const countLabels = ['3 models', '2 models', '1 model'];
      text(shareLabels[i], '${share.toStringAsFixed(1)}%');
      final count = data['modelCounts'][i] as int;
      text(countLabels[i], '$count ${count == 1 ? 'model' : 'models'}');
    }
    text('Usage trend', data['trendLabel'] as String);
    text('Nov 2026', data['trendStart'] as String);
    text('11-30', data['trendEnd'] as String);
    final values = (data['trend'] as List).whereType<num>().toList();
    final maxValue = values.fold<num>(
        0, (current, value) => value > current ? value : current);
    final scaleMax = maxValue <= 0 ? 1 : maxValue;
    final cachedValues = data['trendCached'] is List
        ? (data['trendCached'] as List).whereType<num>().toList()
        : const <num>[];
    final otherValues = data['trendOther'] is List
        ? (data['trendOther'] as List).whereType<num>().toList()
        : const <num>[];
    final templateIndex = FigmaLayerBindings.rectangleAt(
      layers,
      x: 36,
      y: 698,
      width: 7,
      height: 12,
    );
    final cacheIndex = FigmaLayerBindings.rectangleAt(
      layers,
      x: 36,
      y: 698,
      width: 7,
      height: 12,
      occurrence: 1,
    );
    final otherIndex = FigmaLayerBindings.rectangleAt(
      layers,
      x: 36,
      y: 698,
      width: 7,
      height: 7,
    );
    final template = layers[templateIndex];
    final cacheColor = layers[cacheIndex]['c'];
    final otherColor = layers[otherIndex]['c'];
    final chart = <Map<String, dynamic>>[];
    for (var i = 0; i < values.length; i++) {
      final total = values[i] < 0 ? 0 : values[i];
      final cached = (i < cachedValues.length ? cachedValues[i] : 0)
          .clamp(0, total)
          .toDouble();
      final other = (i < otherValues.length ? otherValues[i] : 0)
          .clamp(0, total - cached)
          .toDouble();
      final totalHeight = total / scaleMax * 110;
      final cachedHeight = cached / scaleMax * 110;
      final otherHeight = other / scaleMax * 110;
      final bar = {
        ...template,
        'x': 36 + i * 308 / values.length,
        'y': 710 - totalHeight,
        'w': (308 / values.length - 4).clamp(1, 24),
        'h': totalHeight
      };

      // Paint the total first, then stack its cached/other portions from the
      // baseline so updated records change both bar height and segment size.
      chart.add(bar);
      if (cachedHeight > 0) {
        chart.add({
          ...bar,
          'c': cacheColor,
          'y': 710 - cachedHeight,
          'h': cachedHeight,
        });
      }
      if (otherHeight > 0) {
        chart.add({
          ...bar,
          'c': otherColor,
          'y': 710 - cachedHeight - otherHeight,
          'h': otherHeight,
        });
      }
    }
    final chartIndices = [
      for (var i = 0; i < layers.length; i++)
        if (layers[i]['t'] == 'r' &&
            ((layers[i]['x'] as num?)?.toDouble() ?? -1) >= 36 &&
            ((layers[i]['x'] as num?)?.toDouble() ?? -1) <= 340 &&
            ((layers[i]['y'] as num?)?.toDouble() ?? -1) >= 600 &&
            ((layers[i]['y'] as num?)?.toDouble() ?? -1) <= 710 &&
            ((layers[i]['w'] as num?)?.toDouble() ?? 999) <= 7)
          i,
    ];
    if (chartIndices.isNotEmpty) {
      final insertionIndex = chartIndices.first;
      for (final index in chartIndices.reversed) {
        layers.removeAt(index);
      }
      layers.insertAll(insertionIndex, chart);
    }
    return FigmaMockScreen(
        nodeId: original.nodeId,
        name: original.name,
        width: original.width,
        height: original.height,
        layers: layers);
  }

  static Future<List<FigmaMockHotspot>> hotspots(String screenId) async {
    final exported = await _loadFile(
      'lib/core/mock/data/figma_proto_hotspots.json',
    );
    final demo = await demoInteractions();
    final original = exported[screenId];
    final extra = (demo['areas'] as Map?)?[screenId];
    final data = [
      if (original is List) ...original,
      if (extra is List) ...extra,
    ];
    return data
        .whereType<Map>()
        .map((row) => FigmaMockHotspot.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }
}

@immutable
class FigmaMockScreen {
  const FigmaMockScreen({
    required this.nodeId,
    required this.name,
    required this.width,
    required this.height,
    required this.layers,
  });

  factory FigmaMockScreen.fromJson(Map<String, dynamic> data) =>
      FigmaMockScreen(
        nodeId: (data['figmaNode'] ?? '').toString(),
        name: (data['name'] ?? '').toString(),
        width: (data['w'] as num).toDouble(),
        height: (data['h'] as num).toDouble(),
        layers: (data['layers'] as List)
            .whereType<Map>()
            .map((layer) => Map<String, dynamic>.from(layer))
            .toList(growable: false),
      );

  final String nodeId;
  final String name;
  final double width;
  final double height;
  final List<Map<String, dynamic>> layers;
}

@immutable
class FigmaMockHotspot {
  const FigmaMockHotspot({
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.radius = 0,
  });

  factory FigmaMockHotspot.fromJson(Map<String, dynamic> data) =>
      FigmaMockHotspot(
        name: (data['n'] ?? '').toString(),
        x: (data['x'] as num).toDouble(),
        y: (data['y'] as num).toDouble(),
        width: (data['w'] as num).toDouble(),
        height: (data['h'] as num).toDouble(),
        radius: (data['rad'] as num?)?.toDouble() ?? 0,
      );

  final String name;
  final double x;
  final double y;
  final double width;
  final double height;
  final double radius;
}
