import 'package:flutter/material.dart';

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
      const SizedBox(height: 1, child: ColoredBox(color: UtColors.cardBorder));
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
