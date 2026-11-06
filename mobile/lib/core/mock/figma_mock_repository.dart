import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  });

  factory FigmaMockHotspot.fromJson(Map<String, dynamic> data) =>
      FigmaMockHotspot(
        name: (data['n'] ?? '').toString(),
        x: (data['x'] as num).toDouble(),
        y: (data['y'] as num).toDouble(),
        width: (data['w'] as num).toDouble(),
        height: (data['h'] as num).toDouble(),
      );

  final String name;
  final double x;
  final double y;
  final double width;
  final double height;
}
