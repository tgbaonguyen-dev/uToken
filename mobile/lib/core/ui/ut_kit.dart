import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../data/replay_stream.dart';
import '../data/stream_status.dart';
import '../i18n/tr.dart';
import 'ut_motion.dart';

export 'ut_motion.dart';

/// Dark design tokens taken from the Figma "07 - Final UI Dark" exports
/// (lib/core/mock/data/figma_dark_*.json).
class UtColors {
  UtColors._();

  static const background = Color(0xFF080A0D);
  static const card = Color(0xFF111418);
  static const cardBorder = Color(0xFF292F36);
  static const chip = Color(0xFF171B20);
  static const text = Color(0xFFF2F3F5);
  static const muted = Color(0xFF8C929B);
  static const orange = Color(0xFFF26A45);
  static const blue = Color(0xFF5C8FEF);
  static const green = Color(0xFF39C995);
  static const primaryButton = Color(0xFFF2F3F5);
  static const primaryButtonText = Color(0xFF0A0C0E);
  static const secondaryButton = Color(0xFF121519);
  static const secondaryButtonText = Color(0xFFECEEF1);
}

class UtText {
  UtText._();

  static const _family = 'BeVietnamPro';

  static const hero = TextStyle(
      fontFamily: _family,
      fontSize: 38,
      height: 46 / 38,
      fontWeight: FontWeight.w700,
      color: UtColors.text);
  static const code = TextStyle(
      fontFamily: _family,
      fontSize: 34,
      height: 42 / 34,
      fontWeight: FontWeight.w700,
      color: UtColors.text);
  static const title = TextStyle(
      fontFamily: _family,
      fontSize: 20,
      height: 28 / 20,
      fontWeight: FontWeight.w600,
      color: UtColors.text);
  static const button = TextStyle(
      fontFamily: _family,
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w600);
  static const body = TextStyle(
      fontFamily: _family,
      fontSize: 13,
      height: 20 / 13,
      fontWeight: FontWeight.w400,
      color: UtColors.muted);
  static const bodyStrong = TextStyle(
      fontFamily: _family,
      fontSize: 13,
      height: 20 / 13,
      fontWeight: FontWeight.w500,
      color: UtColors.text);
  static const label = TextStyle(
      fontFamily: _family,
      fontSize: 11,
      height: 16 / 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.8,
      color: UtColors.muted);
  static const caption = TextStyle(
      fontFamily: _family,
      fontSize: 11,
      height: 16 / 11,
      fontWeight: FontWeight.w400,
      color: UtColors.muted);
}

/// Key used by tests and the old hotspot layer, so both UIs stay drivable
/// by the same action names.
Key utActionKey(String name) => ValueKey('figma-hotspot-$name');

/// Bordered surface (Figma: #111418, 1px #292F36, radius 20).
class UtCard extends StatelessWidget {
  const UtCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.fromLTRB(16, 22, 16, 22)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: UtColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: UtColors.cardBorder),
        ),
        child: child,
      );
}

class UtDivider extends StatelessWidget {
  const UtDivider({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
      height: 1,
      width: double.infinity,
      child: ColoredBox(color: UtColors.cardBorder));
}

enum UtButtonStyle { primary, secondary }

/// Full-width 48px action button (Figma: radius 14, y=2 blur=5 shadow).
class UtButton extends StatelessWidget {
  const UtButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.style = UtButtonStyle.primary,
      this.actionName});

  final String label;
  final VoidCallback? onPressed;
  final UtButtonStyle style;

  /// Name used for the test key; defaults to [label].
  final String? actionName;

  @override
  Widget build(BuildContext context) {
    final primary = style == UtButtonStyle.primary;
    final bg = primary ? UtColors.primaryButton : UtColors.secondaryButton;
    final fg =
        primary ? UtColors.primaryButtonText : UtColors.secondaryButtonText;
    final enabled = onPressed != null;
    return UtPressScale(
        enabled: enabled,
        child: AnimatedOpacity(
            duration: UtMotion.medium,
            opacity: enabled ? 1 : 0.45,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x1A000000),
                      offset: Offset(0, 2),
                      blurRadius: 5)
                ],
              ),
              child: Material(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: utActionKey(actionName ?? label),
                  onTap: enabled
                      ? () {
                          HapticFeedback.lightImpact();
                          onPressed!();
                        }
                      : null,
                  child: Center(
                      child: UtSwap(
                          alignment: Alignment.center,
                          child: Text(label,
                              key: ValueKey(label),
                              style: UtText.button.copyWith(color: fg)))),
                ),
              ),
            )));
  }
}

/// Smaller bordered button used inside cards (Figma "Copy code": 42px, r12).
class UtChipButton extends StatelessWidget {
  const UtChipButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => UtPressScale(
      enabled: onPressed != null,
      child: Material(
        color: UtColors.chip,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: UtColors.cardBorder)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: utActionKey(label),
          onTap: onPressed == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                },
          child: SizedBox(
              height: 48,
              child: Center(child: Text(label, style: UtText.bodyStrong))),
        ),
      ));
}

/// Dark page frame: 20px gutters, optional back header, scrollable body and
/// actions pinned to the bottom (Figma buttons sit at y=652..760 of 844).
class UtPage extends StatelessWidget {
  const UtPage({
    super.key,
    required this.children,
    this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
    this.footer,
  });

  final String? title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> children;
  final List<Widget> actions;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    // Figma frames reserve 44px for the status bar and leave 84px under the
    // last action (44px when a footer line sits there).
    final insets = MediaQuery.viewPaddingOf(context);
    final top = insets.top > 38 ? insets.top : 38.0;
    // Keep pinned actions above the system nav bar and above a floating
    // snackbar (16px margin + ~48px), so a notice never covers the button.
    final bottom = insets.bottom + (footer == null ? 72.0 : 28.0);
    return Scaffold(
      backgroundColor: UtColors.background,
      body: Padding(
        padding: EdgeInsets.only(top: top),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              _Header(title: title!, subtitle: subtitle, onBack: onBack),
            const UtOfflineStrip(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children),
              ),
            ),
            if (actions.isNotEmpty || footer != null)
              Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      actions[i],
                    ],
                    if (footer != null) ...[
                      const SizedBox(height: 20),
                      footer!,
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.subtitle, this.onBack});

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            SizedBox(
              width: 48,
              height: 48,
              child: onBack == null
                  ? null
                  : Semantics(
                      label: tr('Back'),
                      button: true,
                      child: InkResponse(
                        key: utActionKey('Back'),
                        onTap: onBack,
                        radius: 24,
                        child: const Center(
                          child: Icon(Icons.arrow_back_rounded,
                              size: 22, color: UtColors.text),
                        ),
                      ),
                    ),
            ),
            Expanded(child: Text(title, style: UtText.title)),
          ]),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 10),
              child: Text(subtitle!, style: UtText.body),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 0, 38),
            child: UtDivider(),
          ),
        ],
      ),
    );
  }
}

void utShowNotice(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16)));
}

// ---------------------------------------------------------------------------
// Tab screens, lists and data states.

class UtTabColors {
  UtTabColors._();
  static const dock = Color(0xFF0C0F13);
  static const dockDivider = Color(0xFF252A31);
  static const inactive = Color(0xFF7B818A);
  static const segmentSelected = Color(0xFF20252B);
}

/// Top-level screen with title, optional refresh and the Figma bottom dock.
class UtTabPage extends StatelessWidget {
  const UtTabPage({
    super.key,
    required this.title,
    required this.tabIndex,
    required this.body,
    this.subtitle,
    this.onRefresh,
    this.largeTitle = true,
  });

  final String title;
  final String? subtitle;
  final bool largeTitle;
  final int tabIndex;
  final Widget body;
  final Future<void> Function()? onRefresh;

  static const tabs = [
    ('Tokens', Icons.data_usage_rounded, '/tokens'),
    ('Analytics', Icons.show_chart_rounded, '/analytics'),
    ('Insights', Icons.lightbulb_outline_rounded, '/insights'),
    ('Settings', Icons.tune_rounded, '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewPaddingOf(context);
    return _TabBackHandler(
        tabIndex: tabIndex,
        child: Scaffold(
          backgroundColor: UtColors.background,
          body: Padding(
            padding: EdgeInsets.only(top: insets.top > 38 ? insets.top : 38),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(children: [
                    Expanded(
                        child: Text(title,
                            style: largeTitle
                                ? UtText.title.copyWith(
                                    fontSize: 30,
                                    height: 38 / 30,
                                    fontWeight: FontWeight.w700)
                                : UtText.title)),
                    if (onRefresh != null)
                      UtRefreshButton(onRefresh: onRefresh!),
                  ]),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                    child: Text(subtitle!, style: UtText.body),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: UtDivider(),
                ),
                const UtOfflineStrip(),
                Expanded(
                    child: onRefresh == null
                        ? body
                        : RefreshIndicator(
                            color: UtColors.text,
                            backgroundColor: UtColors.card,
                            onRefresh: () => utRunRefresh(context, onRefresh!),
                            child: body)),
              ],
            ),
          ),
          bottomNavigationBar: _Dock(selected: tabIndex),
        ));
  }
}

/// Android back on a tab: other tabs return to Tokens; on Tokens a second
/// press within 2 s leaves the app, so one stray swipe doesn't close it.
class _TabBackHandler extends StatefulWidget {
  const _TabBackHandler({required this.tabIndex, required this.child});
  final int tabIndex;
  final Widget child;

  @override
  State<_TabBackHandler> createState() => _TabBackHandlerState();
}

class _TabBackHandlerState extends State<_TabBackHandler> {
  DateTime? _lastBack;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    final canPopRoute = router?.canPop() ?? false;
    return PopScope(
      canPop: canPopRoute,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (widget.tabIndex != 0) {
          context.go(UtTabPage.tabs.first.$3);
          return;
        }
        final now = DateTime.now();
        if (_lastBack != null &&
            now.difference(_lastBack!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBack = now;
        utShowNotice(context, tr('Press back again to exit'));
      },
      child: widget.child,
    );
  }
}

class _Dock extends StatelessWidget {
  const _Dock({required this.selected});
  final int selected;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      color: UtTabColors.dock,
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(
            height: 1, child: ColoredBox(color: UtTabColors.dockDivider)),
        SizedBox(
          height: 68,
          child: Row(children: [
            for (var i = 0; i < UtTabPage.tabs.length; i++)
              Expanded(child: _DockTab(index: i, selected: i == selected)),
          ]),
        ),
      ]),
    );
  }
}

class _DockTab extends StatelessWidget {
  const _DockTab({required this.index, required this.selected});
  final int index;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final (label, icon, route) = UtTabPage.tabs[index];
    final color = selected ? UtColors.text : UtTabColors.inactive;
    return Semantics(
      label: tr(label),
      button: true,
      selected: selected,
      child: InkWell(
        key: ValueKey('utoken-tab-$index'),
        onTap: selected
            ? null
            : () {
                HapticFeedback.selectionClick();
                context.go(route);
              },
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: selected ? 60 : 44,
              height: 30,
              decoration: BoxDecoration(
                  color: selected
                      ? UtTabColors.segmentSelected
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(15)),
              child: AnimatedScale(
                scale: selected ? 1.08 : 1,
                duration: UtMotion.medium,
                curve: UtMotion.spring,
                child: Icon(icon, size: 22, color: color),
              ),
            ),
            const SizedBox(height: 4),
            ExcludeSemantics(
              child: Text(tr(label),
                  style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: selected ? 11 : 10.5,
                      height: 18 / 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: color)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 44px square refresh button (Figma "↻" in a bordered box).
/// Runs a refresh and reports the result in a snackbar. Shared by the header
/// button and pull-to-refresh so both behave the same.
Future<void> utRunRefresh(
    BuildContext context, Future<void> Function() onRefresh) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  void notice(String text) => messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16)));
  try {
    await onRefresh();
    notice(tr('Up to date with the cloud.'));
  } catch (error) {
    notice(friendlyStreamError(error));
  }
}

class UtRefreshButton extends StatefulWidget {
  const UtRefreshButton({super.key, required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  State<UtRefreshButton> createState() => _UtRefreshButtonState();
}

class _UtRefreshButtonState extends State<UtRefreshButton>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  late final _spin = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800));

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_busy) return;
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    _spin.repeat();
    try {
      await utRunRefresh(context, widget.onRefresh);
    } finally {
      // Finish the current turn so the icon lands upright.
      _spin.stop();
      if (mounted) {
        _spin
            .animateTo(1, duration: UtMotion.medium, curve: UtMotion.curve)
            .then((_) => _spin.value = 0);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Tooltip(
      message: tr('Refresh from Firebase'),
      child: Material(
        color: UtColors.background,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
            side: const BorderSide(color: UtColors.cardBorder)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: utActionKey('Refresh'),
          onTap: _busy ? null : _run,
          child: UtPressScale(
            scale: 0.9,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: RotationTransition(
                  turns: _spin,
                  child: Icon(Icons.refresh_rounded,
                      size: 18, color: _busy ? UtColors.muted : UtColors.text),
                ),
              ),
            ),
          ),
        ),
      ));
}

/// Pill segmented control (Figma: 40px track #111418 r14, thumb #20252B r11).
class UtSegmented<T> extends StatelessWidget {
  const UtSegmented(
      {super.key,
      required this.values,
      required this.selected,
      required this.label,
      required this.onChanged});

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final index = values.indexOf(selected).clamp(0, values.length - 1);
    final n = values.length;
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: UtColors.card, borderRadius: BorderRadius.circular(14)),
      child: Stack(children: [
        // One thumb that slides to the chosen segment.
        AnimatedAlign(
          duration: UtMotion.medium,
          curve: UtMotion.curve,
          alignment: Alignment(n == 1 ? 0 : -1 + 2 * index / (n - 1), 0),
          child: FractionallySizedBox(
            widthFactor: 1 / n,
            heightFactor: 1,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: UtTabColors.segmentSelected,
                    borderRadius: BorderRadius.circular(11))),
          ),
        ),
        Row(children: [
          for (final v in values)
            Expanded(
              child: Semantics(
                button: true,
                selected: v == selected,
                child: GestureDetector(
                  key: utActionKey(label(v)),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (v == selected) return;
                    HapticFeedback.selectionClick();
                    onChanged(v);
                  },
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: UtMotion.medium,
                      style: UtText.bodyStrong.copyWith(
                          color:
                              v == selected ? UtColors.text : UtColors.muted),
                      child: Text(label(v)),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

class UtSectionLabel extends StatelessWidget {
  const UtSectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(child: Text(text, style: UtText.label)),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Two-line row with optional trailing value and chevron.
class UtRow extends StatelessWidget {
  const UtRow(
      {super.key,
      required this.title,
      this.subtitle,
      this.trailing,
      this.onTap,
      this.leading,
      this.actionName});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;
  final String? actionName;

  @override
  Widget build(BuildContext context) {
    final row = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: UtText.bodyStrong),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: UtText.caption),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: UtColors.muted),
            ],
          ]),
        ));
    if (onTap == null) return row;
    return InkWell(
        key: utActionKey(actionName ?? title),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        child: row);
  }
}

class UtValue extends StatelessWidget {
  const UtValue(this.text, {super.key, this.color = UtColors.text});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => UtSwap(
      alignment: Alignment.centerRight,
      child: Text(text,
          key: ValueKey(text),
          style: UtText.bodyStrong
              .copyWith(fontWeight: FontWeight.w600, color: color)));
}

enum UtTone { good, review, neutral, danger }

class UtPill extends StatelessWidget {
  const UtPill(this.text, {super.key, this.tone = UtTone.neutral});
  final String text;
  final UtTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      UtTone.good => UtColors.green,
      UtTone.review => UtColors.orange,
      UtTone.danger => const Color(0xFFE0525B),
      UtTone.neutral => UtColors.muted,
    };
    return AnimatedContainer(
      duration: UtMotion.medium,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style: UtText.caption
              .copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

/// Centered message for empty or failed data.
class UtMessage extends StatelessWidget {
  const UtMessage(
      {super.key,
      required this.title,
      required this.message,
      this.icon = Icons.inbox_outlined,
      this.action});
  final String title, message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => UtEntrance(
          child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: UtColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: UtColors.cardBorder)),
            child: Icon(icon, color: UtColors.muted),
          ),
          const SizedBox(height: 20),
          Text(title,
              textAlign: TextAlign.center,
              style: UtText.title.copyWith(fontSize: 18)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: UtText.body),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ]),
      ));
}

/// StreamBuilder with the shared loading and error states.
class UtStream<T> extends StatelessWidget {
  const UtStream({super.key, required this.stream, required this.builder});
  final Stream<T> stream;
  final Widget Function(BuildContext context, T data) builder;

  @override
  Widget build(BuildContext context) {
    // A cached stream already holds the value: draw it on the first frame,
    // with no spinner and no fade.
    final s = stream;
    final cached = s is ReplayStream<T> && s.hasValue;
    return StreamBuilder<T>(
      stream: stream,
      initialData: cached ? s.value : null,
      builder: (context, snapshot) {
        if (cached &&
            !snapshot.hasError &&
            snapshot.connectionState == ConnectionState.waiting) {
          return _FadeInOnce(skip: true, child: builder(context, s.value));
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: UtMessage(
                icon: Icons.cloud_off_outlined,
                title: tr('Couldn’t load data'),
                message: friendlyStreamError(snapshot.error!)),
          );
        }
        // A null value (e.g. a document that doesn't exist yet) is real
        // data once the stream has emitted; only wait for the first event.
        if (!snapshot.hasData &&
            (snapshot.connectionState == ConnectionState.waiting ||
                snapshot.connectionState == ConnectionState.none)) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child:
                Center(child: CircularProgressIndicator(color: UtColors.muted)),
          );
        }
        return _FadeInOnce(
            skip: cached, child: builder(context, snapshot.data as T));
      },
    );
  }
}

/// Fades the data in when it first replaces the spinner; later stream
/// updates rebuild in place (values animate through [UtSwap]).
class _FadeInOnce extends StatelessWidget {
  const _FadeInOnce({required this.child, this.skip = false});
  final Widget child;

  /// Data came from the cache: show it at full opacity right away.
  final bool skip;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: skip ? 1 : 0, end: 1),
        duration: UtMotion.medium,
        curve: UtMotion.curve,
        // Keep Opacity even at 1.0 (no layer then): swapping it out would
        // remount the page and lose its scroll position.
        builder: (_, t, c) => Opacity(opacity: t, child: c),
        child: child,
      );
}

/// Scrollable column with the 20px Figma gutters.
class UtList extends StatelessWidget {
  const UtList({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
        // Always scrollable so pull-to-refresh works on short pages too.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          for (var i = 0; i < children.length; i++)
            UtEntrance(index: i, child: children[i]),
        ],
      );
}

/// Rows separated by 1px dividers, as in the Figma list cards.
class UtRowGroup extends StatelessWidget {
  const UtRowGroup({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const UtDivider(),
          children[i],
        ],
      ]);
}

/// Compact bordered button for inline actions (Figma "Sync now", r11).
/// 40px tall, with the shared press scale and haptic.
class UtChipButtonSmall extends StatelessWidget {
  const UtChipButtonSmall(
      {super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => UtPressScale(
        child: Material(
          color: UtColors.chip,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
              side: const BorderSide(color: UtColors.cardBorder)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: utActionKey(label),
            onTap: () {
              HapticFeedback.selectionClick();
              onPressed();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  widthFactor: 1,
                  child: Text(label,
                      style: UtText.caption.copyWith(
                          color: UtColors.text, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Shared offline flag, set from Firestore snapshot metadata
/// (see OfflineMonitor). Pages show a slim strip while it is true.
final utOffline = ValueNotifier<bool>(false);

/// "Offline · showing saved data" strip under page headers.
class UtOfflineStrip extends StatelessWidget {
  const UtOfflineStrip({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: utOffline,
        builder: (context, offline, _) => AnimatedSize(
          duration: UtMotion.medium,
          curve: UtMotion.curve,
          child: !offline
              ? const SizedBox(width: double.infinity)
              : Padding(
                  key: const ValueKey('offline-strip'),
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: UtColors.chip,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: UtColors.cardBorder)),
                    child: Row(children: [
                      const Icon(Icons.cloud_off_rounded,
                          size: 16, color: UtColors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                            tr(
                                'Offline · showing saved data. It updates when you reconnect.'),
                            style:
                                UtText.caption.copyWith(color: UtColors.text)),
                      ),
                    ]),
                  ),
                ),
        ),
      );
}
