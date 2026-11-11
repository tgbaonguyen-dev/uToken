import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kTouchSlop;

/// Shared motion tokens so every interaction moves the same way.
class UtMotion {
  UtMotion._();
  static const fast = Duration(milliseconds: 120);
  static const medium = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 360);
  static const curve = Curves.easeOutCubic;
  static const spring = Curves.easeOutBack;
}

/// Shrinks its child slightly while a finger is down, then springs back.
/// Uses a raw [Listener], so it never competes with the child's gestures.
class UtPressScale extends StatefulWidget {
  const UtPressScale(
      {super.key, required this.child, this.enabled = true, this.scale = 0.97});
  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<UtPressScale> createState() => _UtPressScaleState();
}

class _UtPressScaleState extends State<UtPressScale> {
  bool _down = false;
  Offset? _origin;

  void _set(bool v) {
    if (!widget.enabled || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (e) {
          _origin = e.position;
          _set(true);
        },
        // A drag means the user is scrolling, not pressing: release early.
        onPointerMove: (e) {
          if (_down &&
              _origin != null &&
              (e.position - _origin!).distance > kTouchSlop) {
            _set(false);
          }
        },
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: _down ? UtMotion.fast : UtMotion.medium,
          curve: _down ? Curves.easeOut : UtMotion.spring,
          child: widget.child,
        ),
      );
}

/// Fades and lifts its child in once, after [index] × 30ms, so list
/// content cascades in instead of popping all at once.
class UtEntrance extends StatelessWidget {
  const UtEntrance({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    // Short cascade: the last card is fully in by ~430ms, and anything past
    // the 6th item (usually off-screen) starts with it.
    final delay = (index.clamp(0, 5)) * 30;
    final total = 280 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (context, t, child) {
        // Hold at 0 for the delay part, then ease over the rest.
        final start = delay / total;
        final p = t <= start
            ? 0.0
            : UtMotion.curve.transform((t - start) / (1 - start));
        return Opacity(
          opacity: p,
          child: Transform.translate(
              offset: Offset(0, (1 - p) * 14), child: child),
        );
      },
      child: child,
    );
  }
}

/// Cross-fades when [child] changes identity (key or text), e.g. a number
/// updating after a sync or a period switch.
class UtSwap extends StatelessWidget {
  const UtSwap(
      {super.key, required this.child, this.alignment = Alignment.centerLeft});
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: UtMotion.medium,
        switchInCurve: UtMotion.curve,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (current, previous) => Stack(
            alignment: alignment,
            children: [...previous, if (current != null) current]),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.25), end: Offset.zero)
                .animate(animation),
            child: child,
          ),
        ),
        child: child,
      );
}
