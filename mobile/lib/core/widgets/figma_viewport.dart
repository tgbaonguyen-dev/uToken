import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Preserve the reference width; short windows scroll instead of shrinking text.
class FigmaViewport extends StatelessWidget {
  const FigmaViewport(
      {super.key,
      required this.width,
      required this.height,
      required this.builder,
      this.footerBuilder});

  final double width;
  final double height;
  final Widget Function(double scale) builder;
  final Widget Function(double scale)? footerBuilder;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final fontScale = MediaQuery.textScalerOf(context).scale(16) / 16;
          // Fixed Figma layers cannot reflow independently. Enlarge the complete
          // canvas and allow panning so large text does not overlap other layers.
          final scale = math.min(constraints.maxWidth / width, 1.0) *
              math.max(fontScale, 1.0);
          return Stack(children: [
            Positioned.fill(
                child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                        minWidth: constraints.maxWidth),
                    child: Center(
                        child: SizedBox(
                            width: width * scale,
                            height: height * scale,
                            child: MediaQuery.withNoTextScaling(
                                child: builder(scale)))),
                  )),
            )),
            if (footerBuilder != null)
              Positioned(
                  bottom: 0,
                  left: (constraints.maxWidth -
                          width * math.min(constraints.maxWidth / width, 1.0)) /
                      2,
                  width: width * math.min(constraints.maxWidth / width, 1.0),
                  height: 68 * math.min(constraints.maxWidth / width, 1.0),
                  child: MediaQuery.withNoTextScaling(
                      child: footerBuilder!(
                          math.min(constraints.maxWidth / width, 1.0)))),
          ]);
        }),
      );
}
