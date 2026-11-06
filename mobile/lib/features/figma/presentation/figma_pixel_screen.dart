import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../app/figma_routes.dart';
import '../../../core/mock/figma_mock_repository.dart';

/// Draws the actual Figma elements, without replacing screens with screenshots.
///
/// The design is 390 × 844. Shapes and SVGs come from Figma, visible copy comes
/// exclusively from mock JSON, and tap targets are exported from PROTO frames.
class FigmaPixelScreen extends StatefulWidget {
  const FigmaPixelScreen({super.key, required this.screenId});

  final String screenId;

  @override
  State<FigmaPixelScreen> createState() => _FigmaPixelScreenState();
}

class _FigmaPixelScreenState extends State<FigmaPixelScreen> {
  Future<FigmaMockScreen>? _screenFuture;
  Future<List<FigmaMockHotspot>>? _hotspotsFuture;
  String? _loadedScreenId;

  @override
  void initState() {
    super.initState();
    _hotspotsFuture = FigmaMockRepository.hotspots(widget.screenId);
  }

  Brightness? _loadedBrightness;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadScreenIfNeeded(Theme.of(context).brightness);
  }

  @override
  void didUpdateWidget(covariant FigmaPixelScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.screenId != widget.screenId) {
      _selectedHotspot = null;
      _hotspotsFuture = FigmaMockRepository.hotspots(widget.screenId);
      _loadScreenIfNeeded(_loadedBrightness ?? Brightness.light);
    }
  }

  void _loadScreenIfNeeded(Brightness brightness) {
    if (_screenFuture != null &&
        _loadedScreenId == widget.screenId &&
        _loadedBrightness == brightness) {
      return;
    }
    _loadedScreenId = widget.screenId;
    _loadedBrightness = brightness;
    _screenFuture = FigmaMockRepository.screen(widget.screenId, brightness);
  }

  static Future<Map<String, dynamic>>? _navigationFuture;

  Future<Map<String, dynamic>> get _navigation =>
      _navigationFuture ??= _loadNavigation();

  static Future<Map<String, dynamic>> _loadNavigation() async {
    final raw = await rootBundle.loadString(
      'lib/core/mock/data/figma_navigation_targets.json',
    );
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  String? _selectedHotspot;

  void _showNotice(String message) {
    if (message.isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
            left: 16, right: 16, bottom: _hasBottomBar ? 88 : 16),
      ),
    );
  }

  Future<void> _handleHotspot(String name) async {
    final demo = await FigmaMockRepository.demoInteractions();
    if (!mounted) return;

    final allActions = demo['actions'];
    final currentActions =
        allActions is Map ? allActions[widget.screenId] : null;
    final action = currentActions is Map ? currentActions[name] : null;
    if (action is Map) {
      final message = action['message']?.toString() ?? '';
      switch (action['type']?.toString()) {
        case 'route':
          final target = action['target']?.toString();
          final route = target == null ? null : figmaPathFor(target);
          if (route != null) {
            context.push(route);
            return;
          }
        case 'select':
          setState(() => _selectedHotspot = name);
          _showNotice(message);
          return;
        case 'copy':
          await Clipboard.setData(
            ClipboardData(text: action['value']?.toString() ?? ''),
          );
          if (mounted) _showNotice(message);
          return;
        case 'notice':
          _showNotice(message);
          return;
      }
    }

    final nav = await _navigation;
    if (!mounted) return;
    if (name == 'Back' || name == 'Close' || name == 'Dismiss') {
      if (context.canPop()) {
        context.pop();
        return;
      }
    }

    final targets = nav['routes'] as Map<String, dynamic>;
    final screenTargets = targets[widget.screenId] as Map<String, dynamic>?;
    final target = screenTargets?[name]?.toString();
    if (target == null) {
      _showNotice(demo['fallbackMessage']?.toString() ?? '');
      return;
    }
    if (target == '@pop') {
      if (context.canPop()) context.pop();
      return;
    }
    final route = figmaPathFor(target);
    if (route == null) return;
    if (name == 'Sign out') {
      context.go(route);
    } else {
      context.push(route);
    }
  }

  Future<void> _openScreenGallery() async {
    // FigmaMockRepository owns the complete 24-frame manifest.
    // The sheet is synchronous; it never stalls while waiting for assets.
    final ids = FigmaMockRepository.screenIds.toList(growable: false);
    final origin = context;
    await showModalBottomSheet<void>(
      context: origin,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.75,
          child: Column(
            children: [
              const ListTile(
                title: Text('All 24 Figma screens'),
                subtitle:
                    Text('UI Preview: hold a screen title to open this index'),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final id in ids)
                        ListTile(
                          title: Text(id),
                          subtitle: Text(figmaPathFor(id) ?? ''),
                          trailing: const Icon(Icons.chevron_right),
                          selected: id == widget.screenId,
                          onTap: () {
                            final path = figmaPathFor(id);
                            Navigator.of(sheetContext).pop();
                            if (path != null && mounted) origin.go(path);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onBottomTap(int tabIndex) {
    const tabScreenIds = ['M04', 'M05', 'M07', 'M09'];
    if (tabIndex < 0 || tabIndex >= tabScreenIds.length) return;
    final route = figmaPathFor(tabScreenIds[tabIndex]);
    if (route != null) context.go(route);
  }

  bool get _hasBottomBar => const [
        'M04',
        'M05',
        'M07',
        'M09',
        'S01',
        'S02',
        'S03',
        'S04',
      ].contains(widget.screenId);

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final pageBackground =
        brightness == Brightness.dark ? const Color(0xFF080A0D) : Colors.white;

    return Scaffold(
      backgroundColor: pageBackground,
      body: LayoutBuilder(
        builder: (context, constraints) => FutureBuilder<FigmaMockScreen>(
          future: _screenFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    snapshot.error.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                );
              }
              return const SizedBox.expand();
            }
            final screen = snapshot.data!;
            final width = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : screen.width;
            final height = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : screen.height;
            final scale =
                math.min(width / screen.width, height / screen.height);
            final scaledWidth = screen.width * scale;
            final scaledHeight = screen.height * scale;

            return Center(
              child: SizedBox(
                width: scaledWidth,
                height: scaledHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: FittedBox(
                        fit: BoxFit.fill,
                        child: SizedBox(
                          width: screen.width,
                          height: screen.height,
                          child: _buildFigmaCanvas(context, screen),
                        ),
                      ),
                    ),
                    // Preview-only index: accessible without changing the
                    // original Figma appearance (hold any screen title).
                    Positioned(
                      left: 78 * scale,
                      top: 38 * scale,
                      width: 234 * scale,
                      height: 62 * scale,
                      child: GestureDetector(
                        key: const ValueKey('figma-screen-gallery-trigger'),
                        behavior: HitTestBehavior.translucent,
                        onLongPress: _openScreenGallery,
                        child: const SizedBox.expand(),
                      ),
                    ),
                    // Keep the hit targets OUTSIDE the scaled Figma canvas.
                    // This makes tabs reliably hittable on emulators/devices
                    // with non-reference physical dimensions.
                    if (_hasBottomBar)
                      Positioned(
                        left: 0,
                        bottom: 0,
                        width: scaledWidth,
                        height: 68 * scale,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < 4; i++)
                              Expanded(
                                child: GestureDetector(
                                  key: ValueKey('utoken-tab-$i'),
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _onBottomTap(i),
                                  child: const ColoredBox(
                                    color: Colors.transparent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFigmaCanvas(
    BuildContext context,
    FigmaMockScreen screen,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        widget.screenId == 'M01' ? 24 : 28,
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          ...screen.layers.map(_paintLayer),
          FutureBuilder<List<FigmaMockHotspot>>(
            future: _hotspotsFuture,
            builder: (context, snapshot) {
              final spots = snapshot.data;
              if (spots == null) return const SizedBox.shrink();
              return Stack(
                children: [
                  for (final spot in spots)
                    Positioned(
                      left: spot.x,
                      top: spot.y,
                      width: spot.width,
                      height: spot.height,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _handleHotspot(spot.name),
                        child: const ColoredBox(color: Colors.transparent),
                      ),
                    ),
                  for (final spot in spots)
                    if (_selectedHotspot == spot.name)
                      Positioned(
                        left: spot.x,
                        top: spot.y,
                        width: spot.width,
                        height: spot.height,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _paintLayer(Map<String, dynamic> layer) {
    final left = _number(layer['x']);
    final top = _number(layer['y']);
    final width = _number(layer['w']);
    final height = _number(layer['h']);
    if (width <= 0 || height <= 0) return const SizedBox.shrink();

    late final Widget child;
    switch (layer['t']) {
      case 't':
        child = _text(layer);
      case 'a':
        final assetId = layer['id']?.toString() ?? '';
        final fileName = assetId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        child = SvgPicture.asset(
          'assets/figma/$fileName.svg',
          fit: BoxFit.fill,
          placeholderBuilder: (_) => const SizedBox.shrink(),
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        );
      case 'e':
      case 'r':
        child = _shape(layer);
      default:
        child = const SizedBox.shrink();
    }

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: child,
    );
  }

  Widget _shape(Map<String, dynamic> layer) {
    final fill = _color(layer['c']);
    final stroke = _color(layer['b']);
    final border = stroke == null
        ? null
        : Border.all(color: stroke, width: _number(layer['bw'], fallback: 1));

    final isOval = layer['t'] == 'e';
    BorderRadiusGeometry? radius;
    final radii = layer['rs'];
    if (!isOval && radii is List && radii.length == 4) {
      radius = BorderRadius.only(
        topLeft: Radius.circular(_number(radii[0])),
        topRight: Radius.circular(_number(radii[1])),
        bottomRight: Radius.circular(_number(radii[2])),
        bottomLeft: Radius.circular(_number(radii[3])),
      );
    } else if (!isOval) {
      radius = BorderRadius.circular(_number(layer['rad']));
    }

    List<BoxShadow>? shadow;
    if (layer['shadow'] is Map) {
      final data = layer['shadow'] as Map;
      shadow = [
        BoxShadow(
          color: _color(data['c']) ?? Colors.transparent,
          offset: Offset(_number(data['x']), _number(data['y'])),
          blurRadius: _number(data['blur']),
        ),
      ];
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: isOval ? BoxShape.circle : BoxShape.rectangle,
        color: fill,
        border: border,
        borderRadius: radius,
        boxShadow: shadow,
      ),
    );
  }

  Widget _text(Map<String, dynamic> layer) {
    final fontSize = _number(layer['sz'], fallback: 13);
    final lineHeight = _number(layer['lh']);
    final styleName = layer['fw']?.toString() ?? 'Regular';
    final weight = switch (styleName) {
      'Thin' => FontWeight.w100,
      'ExtraLight' => FontWeight.w200,
      'Light' => FontWeight.w300,
      'Medium' => FontWeight.w500,
      'SemiBold' || 'Semi Bold' => FontWeight.w600,
      'Bold' => FontWeight.w700,
      'ExtraBold' => FontWeight.w800,
      'Black' => FontWeight.w900,
      _ => FontWeight.w400,
    };
    final alignment = switch (layer['al']) {
      'CENTER' => TextAlign.center,
      'RIGHT' => TextAlign.right,
      'JUSTIFIED' => TextAlign.justify,
      _ => TextAlign.left,
    };
    final verticalAlignment = switch (layer['va']) {
      'CENTER' => Alignment.center,
      'BOTTOM' => Alignment.bottomCenter,
      _ => Alignment.topCenter,
    };

    return Align(
      alignment: verticalAlignment,
      child: SizedBox.expand(
        child: Text(
          layer['v']?.toString() ?? '',
          textAlign: alignment,
          softWrap: true,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontWeight: weight,
            fontSize: fontSize,
            height: lineHeight > 0 ? lineHeight / fontSize : null,
            letterSpacing: _number(layer['sp']),
            color: _color(layer['c']) ?? Colors.black,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  static double _number(dynamic value, {double fallback = 0}) =>
      value is num ? value.toDouble() : fallback;

  static Color? _color(dynamic value) {
    if (value is! String || !value.startsWith('#')) return null;
    final hex = value.substring(1);
    if (hex.length == 8) return Color(int.parse(hex, radix: 16));
    if (hex.length == 6) return Color(0xFF000000 | int.parse(hex, radix: 16));
    return null;
  }
}
