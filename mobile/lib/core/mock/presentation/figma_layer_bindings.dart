/// Semantic accessors for the exported Figma layer arrays.
///
/// The current JSON export does not retain stable node IDs for text/vector
/// layers, so bindings resolve by semantic source text and visual geometry
/// rather than scattering raw array offsets through presentation code.
class FigmaLayerBindings {
  const FigmaLayerBindings._();

  static int textIndex(
    List<Map<String, dynamic>> layers,
    String sourceText, {
    int occurrence = 0,
  }) {
    final matches = <int>[];
    for (var index = 0; index < layers.length; index++) {
      final layer = layers[index];
      if (layer['t'] == 't' && layer['v']?.toString() == sourceText) {
        matches.add(index);
      }
    }
    if (occurrence >= matches.length) {
      throw StateError('Figma text binding not found: $sourceText');
    }
    return matches[occurrence];
  }

  static int layerAt(
    List<Map<String, dynamic>> layers, {
    required String type,
    required double x,
    required double y,
    double? width,
    double? height,
    int occurrence = 0,
    double tolerance = 1.0,
  }) {
    final matches = <int>[];
    for (var index = 0; index < layers.length; index++) {
      final layer = layers[index];
      final layerX = (layer['x'] as num?)?.toDouble() ?? double.infinity;
      final layerY = (layer['y'] as num?)?.toDouble() ?? double.infinity;
      final layerWidth = (layer['w'] as num?)?.toDouble() ?? double.infinity;
      final layerHeight = (layer['h'] as num?)?.toDouble() ?? double.infinity;
      if (layer['t'] == type &&
          (layerX - x).abs() <= tolerance &&
          (layerY - y).abs() <= tolerance &&
          (width == null || (layerWidth - width).abs() <= tolerance) &&
          (height == null || (layerHeight - height).abs() <= tolerance)) {
        matches.add(index);
      }
    }
    if (occurrence >= matches.length) {
      throw StateError('Figma $type binding not found at ($x, $y)');
    }
    return matches[occurrence];
  }

  static int rectangleAt(
    List<Map<String, dynamic>> layers, {
    required double x,
    required double y,
    double? width,
    double? height,
    int occurrence = 0,
    double tolerance = 1.0,
  }) =>
      layerAt(
        layers,
        type: 'r',
        x: x,
        y: y,
        width: width,
        height: height,
        occurrence: occurrence,
        tolerance: tolerance,
      );

  static int backgroundForText(
    List<Map<String, dynamic>> layers,
    int textLayerIndex,
  ) {
    final textLayer = layers[textLayerIndex];
    final x = (textLayer['x'] as num).toDouble();
    final y = (textLayer['y'] as num).toDouble();
    final width = (textLayer['w'] as num).toDouble();
    final height = (textLayer['h'] as num).toDouble();
    final candidates = <({int index, double area})>[];
    for (var index = 0; index < layers.length; index++) {
      final layer = layers[index];
      if (layer['t'] != 'r') continue;
      final left = (layer['x'] as num?)?.toDouble() ?? double.infinity;
      final top = (layer['y'] as num?)?.toDouble() ?? double.infinity;
      final right = left + ((layer['w'] as num?)?.toDouble() ?? 0);
      final bottom = top + ((layer['h'] as num?)?.toDouble() ?? 0);
      if (left <= x && top <= y && right >= x + width && bottom >= y + height) {
        candidates.add((
          index: index,
          area: (right - left) * (bottom - top),
        ));
      }
    }
    if (candidates.isEmpty) {
      throw StateError(
          'Figma background not found for text layer $textLayerIndex');
    }
    candidates.sort((a, b) => a.area.compareTo(b.area));
    return candidates.first.index;
  }

  static void setText(
    List<Map<String, dynamic>> layers,
    String sourceText,
    Object value, {
    int occurrence = 0,
  }) {
    layers[textIndex(layers, sourceText, occurrence: occurrence)]['v'] =
        value.toString();
  }
}
