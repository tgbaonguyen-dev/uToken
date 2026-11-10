import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/local_prefs.dart';
import '../../core/data/usage_aggregates.dart';
import '../../core/data/usage_repository.dart';
import '../../core/format/token_format.dart';
import '../../core/models/daily_doc.dart';
import '../../core/ui/ut_kit.dart';

/// Signed-in user and the Firestore reader every live screen needs.
class LiveArgs {
  const LiveArgs({required this.uid, required this.repository});
  final String uid;
  final UsageRepository repository;

  /// Reads the server copy and asks the desktop to upload new usage.
  Future<void> refresh() async {
    await repository.refresh(uid: uid);
    try {
      await repository.requestSync(uid: uid);
    } catch (error) {
      debugPrint('Could not ask the desktop to sync: $error');
    }
  }

  /// All daily summaries up to today.
  Stream<List<DailyDoc>> daily() =>
      repository.watchDaily(uid: uid, end: DateTime.now());
}

/// Token count using the user's Compact/Full preference.
String tok(int value) => formatTokens(value, LocalPrefs.instance.tokenFormat);

String compact(int value) => formatTokens(value, TokenFormat.compact);

/// Back-arrow page used by detail screens.
void liveBack(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

String withPeriod(String path, UsagePeriod period) =>
    Uri(path: path, queryParameters: {'period': period.label}).toString();

/// Thin horizontal share bar made of coloured segments.
class ShareBar extends StatelessWidget {
  const ShareBar({super.key, required this.parts, this.height = 6});
  final List<(double, Color)> parts;
  final double height;

  @override
  Widget build(BuildContext context) {
    final visible = parts.where((p) => p.$1 > 0).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: visible.isEmpty
            ? const ColoredBox(color: UtColors.chip)
            : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final p in visible)
                  Expanded(
                      flex: (p.$1 * 1000).round().clamp(1, 1000),
                      child: ColoredBox(color: p.$2)),
              ]),
      ),
    );
  }
}

const _claudePink = Color(0xFFD65B9E);

/// Figma provider colours: Gemini orange, Codex blue, Claude pink.
Color providerColorOf(String provider) => switch (provider) {
      'antigravity' => UtColors.orange,
      'codex' => UtColors.blue,
      'claude_code' => _claudePink,
      _ => UtColors.green,
    };

const providerColors = [UtColors.orange, UtColors.blue, _claudePink];

Color providerColor(int index) => providerColors[index % providerColors.length];

/// Provider logo badge exported from Figma (24×24).
class ProviderBadge extends StatelessWidget {
  const ProviderBadge(this.provider, {super.key, this.size = 24});
  final String provider;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = switch (provider) {
      'antigravity' => 'assets/figma/34_16.svg',
      'codex' => 'assets/figma/34_18.svg',
      'claude_code' => 'assets/figma/34_20.svg',
      _ => null,
    };
    if (asset == null) {
      return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              color: UtColors.chip, borderRadius: BorderRadius.circular(7)));
    }
    return SvgPicture.asset(asset, width: size, height: size);
  }
}

/// Simple vertical bar chart; [values] are drawn left to right.
class BarChart extends StatelessWidget {
  const BarChart(
      {super.key,
      required this.values,
      this.height = 110,
      this.color = UtColors.blue,
      this.highlightLast = false});
  final List<double> values;
  final double height;
  final Color color;
  final bool highlightLast;

  @override
  Widget build(BuildContext context) {
    final max = values.fold<double>(0, (m, v) => v > m ? v : m);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: values.length > 20 ? 1.5 : 4),
                child: Container(
                  height: max == 0
                      ? 2
                      : (values[i] / max * height).clamp(2, height),
                  decoration: BoxDecoration(
                    color: highlightLast && i == values.length - 1
                        ? UtColors.orange
                        : values[i] == 0
                            ? UtColors.chip
                            : color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bars stacked bottom-up from [stacks] (one list of values per bar).
class StackedBarChart extends StatelessWidget {
  const StackedBarChart(
      {super.key,
      required this.stacks,
      required this.colors,
      this.height = 110});
  final List<List<double>> stacks;
  final List<Color> colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    final max = stacks.fold<double>(
        0,
        (m, s) => s.fold<double>(0, (a, b) => a + b) > m
            ? s.fold<double>(0, (a, b) => a + b)
            : m);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final stack in stacks)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: stacks.length > 20 ? 2 : 5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (stack.every((v) => v == 0) || max == 0)
                        const SizedBox(
                            height: 2, child: ColoredBox(color: UtColors.chip)),
                      for (var i = stack.length - 1; i >= 0; i--)
                        if (stack[i] > 0 && max > 0)
                          SizedBox(
                              height: stack[i] / max * height,
                              child: ColoredBox(color: colors[i])),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Label/value pair stacked vertically (Figma mini stats).
class MiniStat extends StatelessWidget {
  const MiniStat({super.key, required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: UtText.bodyStrong
                  .copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(label, style: UtText.caption),
        ],
      );
}
