import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/figma_viewport.dart';
import '../../../core/widgets/ui_preview_scope.dart';
import '../domain/signing_in_state_model.dart';

/// Reference canvas for the reviewed Dark states (390 x 844).
/// Content comes from the mock model; per-state assets/colors come from Figma.
class ReviewedStateView extends StatelessWidget {
  const ReviewedStateView({
    super.key,
    required this.data,
    required this.onAction,
    required this.onBack,
    required this.onSelectState,
    required this.onTab,
    this.onSimulateResult,
  });

  final SigningInStateData data;
  final VoidCallback onAction;
  final VoidCallback onBack;
  final VoidCallback onSelectState;
  final ValueChanged<int> onTab;
  final VoidCallback? onSimulateResult;

  Map<String, dynamic> get spec => data.figmaLayout!;
  int get activeIndex =>
      ['Tokens', 'Analytics', 'Insights', 'Settings'].indexOf(data.activeTab);
  static Color color(String hex) =>
      Color(int.parse(hex.replaceFirst('#', 'ff'), radix: 16));

  Widget text(String value, double size, double line, Color ink,
          {FontWeight weight = FontWeight.w400,
          TextAlign align = TextAlign.left}) =>
      Text(value,
          textAlign: align,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontFamilyFallback: const ['Arial', 'Roboto', 'Segoe UI Symbol'],
            fontSize: size,
            height: line / size,
            fontWeight: weight,
            color: ink,
            decoration: TextDecoration.none,
          ));

  Widget at(double x, double y, double width, Widget child, {double? height}) =>
      Positioned(left: x, top: y, width: width, height: height, child: child);

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xff090a0b),
        body: FigmaViewport(
            width: 390,
            height: 844,
            footerBuilder: data.hasBottomNavigation
                ? (_) => FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox(
                        width: 390,
                        height: 68,
                        child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(28)),
                            child: _navigation())))
                : null,
            builder: (scale) => FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                    width: 390, height: 844, child: _canvas(context)))),
      );

  Widget _canvas(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: ColoredBox(
          color: const Color(0xff090a0b),
          child: Stack(children: [
            at(
                20,
                28,
                350,
                text(data.badgeText, 10, 16, color(spec['badge_color']),
                    weight: FontWeight.w600, align: TextAlign.right)),
            at(
                data.hasBackButton ? 52 : 20,
                52,
                data.hasBackButton ? 318 : 350,
                GestureDetector(
                  key: const ValueKey('reviewed-state-picker'),
                  behavior: HitTestBehavior.opaque,
                  onLongPress:
                      UiPreviewScope.enabledOf(context) ? onSelectState : null,
                  child: text(data.screenTitle, 22, 30, const Color(0xfff4f4f5),
                      weight: FontWeight.w600),
                )),
            if (data.hasBackButton)
              at(
                  12,
                  38,
                  40,
                  Semantics(
                      label: 'Back',
                      button: true,
                      child: GestureDetector(
                        key: const ValueKey('reviewed-state-back'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onBack,
                        child: const Icon(Icons.chevron_left,
                            color: Color(0xff9b9fa8), size: 28),
                      )),
                  height: 44),
            at(
                20,
                94,
                350,
                text(data.specificationSubtitle, 11, 18,
                    color(spec['subtitle_color']),
                    weight: FontWeight.w500)),
            at(20, 142, 350, _card(), height: 260),
            at(
                20,
                438,
                350,
                text(data.behavior.label, 10, 16,
                    color(spec['behavior_label_color']),
                    weight: FontWeight.w600)),
            at(
                20,
                462,
                350,
                text(data.behavior.description, 12, 20,
                    color(spec['behavior_color']))),
            at(
                20,
                (spec['button_top'] as num).toDouble(),
                350,
                AppButton(
                  key: const ValueKey('reviewed-state-action'),
                  label: data.action.buttonLabel,
                  onPressed: onAction,
                  backgroundColor: color(spec['button_background']),
                  textColor: color(spec['button_color']),
                ),
                height: 52),
            if (onSimulateResult != null && UiPreviewScope.enabledOf(context))
              at(
                  20,
                  632,
                  350,
                  OutlinedButton.icon(
                    key: const ValueKey('mock-state-outcome'),
                    onPressed: onSimulateResult,
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Choose demo outcome'),
                  ),
                  height: 44),
          ]),
        ),
      );

  Widget _card() {
    final rect = spec['illustration_rect'] as Map;
    final dots = spec['dots'] as List;
    return Container(
      key: const ValueKey('reviewed-state-card'),
      decoration: BoxDecoration(
        color: const Color(0xff121519),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xff2a2f36)),
      ),
      child: Stack(clipBehavior: Clip.none, children: [
        at(
            (rect['x'] as num).toDouble(),
            (rect['y'] as num).toDouble(),
            (rect['w'] as num).toDouble(),
            SvgPicture.asset(spec['illustration'], fit: BoxFit.fill),
            height: (rect['h'] as num).toDouble()),
        at(
            23,
            82,
            302,
            Column(mainAxisSize: MainAxisSize.min, children: [
              text(data.card.title, 16, 22, const Color(0xfff4f4f5),
                  weight: FontWeight.w600, align: TextAlign.center),
              const SizedBox(height: 5),
              text(data.card.description, 12, 18, const Color(0xff9b9fa8),
                  align: TextAlign.center),
            ])),
        at(23, 152, 302, SvgPicture.asset(spec['divider'], fit: BoxFit.fill),
            height: 1),
        for (var i = 0; i < data.card.items.length && i < 2; i++) ...[
          at(23, 169 + 45.0 * i, 8, SvgPicture.asset(dots[i], fit: BoxFit.fill),
              height: 8),
          at(
              47,
              161 + 45.0 * i,
              278,
              text(data.card.items[i].title, 12, 20, const Color(0xfff4f4f5),
                  weight: FontWeight.w500)),
          at(
              47,
              182 + 45.0 * i,
              278,
              text(data.card.items[i].subtitle, 10, 16,
                  const Color(0xff9b9fa8))),
        ],
      ]),
    );
  }

  Widget _navigation() => Container(
        decoration: const BoxDecoration(
            color: Color(0xff0c0f13),
            border: Border(top: BorderSide(color: Color(0xff252a31)))),
        child: Row(children: [
          for (var i = 0; i < 4; i++)
            Expanded(
                child: Semantics(
                    label: ['Tokens', 'Analytics', 'Insights', 'Settings'][i],
                    button: true,
                    selected: i == activeIndex,
                    child: GestureDetector(
                      key: ValueKey('reviewed-state-tab-$i'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTab(i),
                      child: Stack(children: [
                        if (i == activeIndex)
                          at(
                              20.75,
                              0,
                              56,
                              DecoratedBox(
                                  decoration: BoxDecoration(
                                color: const Color(0xfff2f3f5),
                                borderRadius: BorderRadius.circular(2),
                              )),
                              height: 4),
                        at(
                            i == activeIndex ? 36.75 : 37.75,
                            i == activeIndex ? 9 : 10,
                            i == activeIndex ? 24 : 22,
                            SvgPicture.asset((spec['nav'] as List)[i],
                                fit: BoxFit.fill),
                            height: i == activeIndex ? 24 : 22),
                        at(
                            0,
                            39,
                            97.5,
                            text(
                                [
                                  'Tokens',
                                  'Analytics',
                                  'Insights',
                                  'Settings'
                                ][i],
                                i == activeIndex ? 11 : 10.5,
                                18,
                                i == activeIndex
                                    ? const Color(0xfff2f3f5)
                                    : const Color(0xff7b818a),
                                weight: i == activeIndex
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                align: TextAlign.center)),
                      ]),
                    ))),
        ]),
      );
}
