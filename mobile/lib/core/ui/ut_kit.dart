import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/stream_status.dart';

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
      fontSize: 10,
      height: 16 / 10,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.8,
      color: UtColors.muted);
  static const caption = TextStyle(
      fontFamily: _family,
      fontSize: 10,
      height: 16 / 10,
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
  Widget build(BuildContext context) =>
      const SizedBox(
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
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A000000), offset: Offset(0, 2), blurRadius: 5)
        ],
      ),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: utActionKey(actionName ?? label),
          onTap: onPressed,
          child: Center(
              child: Text(label, style: UtText.button.copyWith(color: fg))),
        ),
      ),
    );
  }
}

/// Smaller bordered button used inside cards (Figma "Copy code": 42px, r12).
class UtChipButton extends StatelessWidget {
  const UtChipButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: UtColors.chip,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: UtColors.cardBorder)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: utActionKey(label),
          onTap: onPressed,
          child: SizedBox(
              height: 42,
              child: Center(child: Text(label, style: UtText.bodyStrong))),
        ),
      );
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
    final minBottom = footer == null ? 84.0 : 44.0;
    final bottom = insets.bottom > minBottom ? insets.bottom : minBottom;
    return Scaffold(
      backgroundColor: UtColors.background,
      body: Padding(
        padding: EdgeInsets.only(top: top),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              _Header(title: title!, subtitle: subtitle, onBack: onBack),
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
                padding: EdgeInsets.fromLTRB(24, 0, 24, bottom),
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
              width: 46,
              height: 46,
              child: onBack == null
                  ? null
                  : Semantics(
                      label: 'Back',
                      button: true,
                      child: InkResponse(
                        key: utActionKey('Back'),
                        onTap: onBack,
                        radius: 22,
                        child: const Center(
                          child: Text('‹',
                              style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 30,
                                  height: 1,
                                  fontWeight: FontWeight.w700,
                                  color: UtColors.muted)),
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
    return Scaffold(
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
                if (onRefresh != null) UtRefreshButton(onRefresh: onRefresh!),
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
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: _Dock(selected: tabIndex),
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
          height: 67,
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
      label: label,
      button: true,
      selected: selected,
      child: InkWell(
        key: ValueKey('utoken-tab-$index'),
        onTap: selected ? null : () => context.go(route),
        child: Stack(alignment: Alignment.topCenter, children: [
          if (selected)
            Container(
                width: 56,
                height: 4,
                decoration: BoxDecoration(
                    color: UtColors.text,
                    borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 8),
              ExcludeSemantics(
                child: Text(label,
                    style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: selected ? 11 : 10.5,
                        height: 18 / 11,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: color)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// 32px square refresh button (Figma "↻" in a bordered box).
class UtRefreshButton extends StatefulWidget {
  const UtRefreshButton({super.key, required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  State<UtRefreshButton> createState() => _UtRefreshButtonState();
}

class _UtRefreshButtonState extends State<UtRefreshButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onRefresh();
      if (mounted) {
        utShowNotice(context,
            'Read latest data from Firebase. New usage requires a desktop upload.');
      }
    } catch (error) {
      if (mounted) utShowNotice(context, friendlyStreamError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Refresh from Firebase',
        child: Material(
          color: UtColors.background,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
              side: const BorderSide(color: UtColors.cardBorder)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: utActionKey('Refresh'),
            onTap: _busy ? null : _run,
            child: SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: UtColors.text))
                    : const Icon(Icons.refresh_rounded,
                        size: 18, color: UtColors.text),
              ),
            ),
          ),
        ),
      );
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
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: UtColors.card, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        for (final v in values)
          Expanded(
            child: Semantics(
              button: true,
              selected: v == selected,
              child: GestureDetector(
                key: utActionKey(label(v)),
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                      color: v == selected
                          ? UtTabColors.segmentSelected
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(11)),
                  alignment: Alignment.center,
                  child: Text(label(v),
                      style: UtText.bodyStrong.copyWith(
                          color:
                              v == selected ? UtColors.text : UtColors.muted)),
                ),
              ),
            ),
          ),
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
    final row = Padding(
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
    );
    if (onTap == null) return row;
    return InkWell(
        key: utActionKey(actionName ?? title), onTap: onTap, child: row);
  }
}

class UtValue extends StatelessWidget {
  const UtValue(this.text, {super.key, this.color = UtColors.text});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(text,
      style: UtText.bodyStrong
          .copyWith(fontWeight: FontWeight.w600, color: color));
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
    return Container(
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
  Widget build(BuildContext context) => Padding(
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
      );
}

/// StreamBuilder with the shared loading and error states.
class UtStream<T> extends StatelessWidget {
  const UtStream({super.key, required this.stream, required this.builder});
  final Stream<T> stream;
  final Widget Function(BuildContext context, T data) builder;

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: UtMessage(
                  icon: Icons.cloud_off_outlined,
                  title: 'Couldn’t load data',
                  message: friendlyStreamError(snapshot.error!)),
            );
          }
          if (!snapshot.hasData &&
              snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                  child: CircularProgressIndicator(color: UtColors.muted)),
            );
          }
          return builder(context, snapshot.data as T);
        },
      );
}

/// Scrollable column with the 20px Figma gutters.
class UtList extends StatelessWidget {
  const UtList({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: children,
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
