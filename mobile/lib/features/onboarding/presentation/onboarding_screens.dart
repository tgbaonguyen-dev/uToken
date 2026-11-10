import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/ut_kit.dart';
import '../../auth/domain/mobile_auth.dart';
import '../../auth/presentation/mobile_auth_status.dart';
import '../../../core/widgets/ui_preview_scope.dart';
import '../../../core/i18n/tr.dart';

void _back(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// M01 — Welcome.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _continue(BuildContext context) async {
    final auth = MobileAuthScope.maybeOf(context);
    if (auth != null) {
      await auth.signIn();
    } else {
      context.push('/ui-state/signingIn');
    }
  }

  void _demo(BuildContext context) {
    MobileAuthScope.maybeOf(context)?.enterDemo();
    context.go('/tokens');
  }

  @override
  Widget build(BuildContext context) {
    return MobileAuthStatus(
      child: UtPage(
        actions: [
          UtButton(
              label: tr('Continue with Google'),
              onPressed: () => _continue(context)),
          // Sample data is only offered in preview builds.
          if (UiPreviewScope.enabledOf(context))
            UtButton(
                label: tr('View demo'),
                style: UtButtonStyle.secondary,
                onPressed: () => _demo(context)),
        ],
        footer: Text(tr('Your prompts stay on your devices.'),
            textAlign: TextAlign.center, style: UtText.caption),
        children: [
          const SizedBox(height: 32),
          const Text('Track your\nAI usage.', style: UtText.hero),
          const SizedBox(height: 12),
          Text(
              tr('Automatic token and cost tracking for the tools you already use.'),
              style: UtText.body),
          const SizedBox(height: 44),
          const _FeatureCard(),
        ],
      ),
    );
  }
}

/// What the app shows once the desktop uploads usage (no sample numbers).
class _FeatureCard extends StatelessWidget {
  const _FeatureCard();

  static const _rows = [
    (
      Icons.data_usage_rounded,
      'Token totals',
      'Codex, Gemini and Claude in one place'
    ),
    (
      Icons.attach_money_rounded,
      'Estimated cost',
      'Priced from the desktop’s model catalog'
    ),
    (
      Icons.lightbulb_outline_rounded,
      'Suggestions',
      'AI review of your usage patterns'
    ),
    (
      Icons.sync_rounded,
      'Synced with your computer',
      'Same Google account on both devices'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return UtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('What you get'), style: UtText.label),
          const SizedBox(height: 8),
          for (final r in _rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: UtColors.chip,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: UtColors.cardBorder)),
                  child: Icon(r.$1, size: 16, color: UtColors.text),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.$2, style: UtText.bodyStrong),
                      Text(r.$3, style: UtText.caption),
                    ],
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

/// M02 — Connect desktop (pairing code preview).
class ConnectDesktopScreen extends StatelessWidget {
  const ConnectDesktopScreen({super.key});

  static const _sampleCode = '8K4 — M2P';

  void _leave(BuildContext context, {required bool paired}) {
    final auth = MobileAuthScope.maybeOf(context);
    if (auth != null) {
      auth.leaveDesktopSetup();
      context.go(paired ? '/waiting-first-usage' : '/tokens');
    } else if (paired) {
      context.push('/ui-state/verifying');
    } else {
      _back(context, '/welcome');
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _sampleCode));
    if (context.mounted) {
      utShowNotice(context,
          tr('Sample pairing code copied. It only works in the UI preview.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAuthStatus(
      child: PopScope(
        canPop: MobileAuthScope.maybeOf(context) == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave(context, paired: false);
        },
        child: UtPage(
          title: tr('Connect desktop'),
          subtitle: tr('Pair the collector running on your computer.'),
          onBack: () => _leave(context, paired: false),
          actions: [
            UtButton(
                label: tr('I’ve paired my device'),
                onPressed: () => _leave(context, paired: true)),
          ],
          children: [
            UtCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  Text(tr('Pairing code'), style: UtText.label),
                  const SizedBox(height: 20),
                  const Text(_sampleCode,
                      textAlign: TextAlign.center, style: UtText.code),
                  const SizedBox(height: 8),
                  Text(tr('Expires in 08:42'),
                      textAlign: TextAlign.center,
                      style: UtText.caption.copyWith(color: UtColors.orange)),
                  const SizedBox(height: 20),
                  UtChipButton(
                      label: tr('Copy code'), onPressed: () => _copy(context)),
                  const SizedBox(height: 32),
                  const UtDivider(),
                  const SizedBox(height: 24),
                  Text(tr('What is shared'), style: UtText.label),
                  const SizedBox(height: 18),
                  _SharedRow(
                      title: tr('Usage totals'),
                      detail: 'Tokens, model, cost, and time',
                      shared: true),
                  const SizedBox(height: 20),
                  _SharedRow(
                      title: tr('Prompt content'),
                      detail: 'Never uploaded',
                      shared: false),
                ],
              ),
            ),
            const SizedBox(height: 94),
            Row(children: [
              Expanded(
                  child:
                      Text(tr('Need the desktop app?'), style: UtText.caption)),
              InkWell(
                key: utActionKey('Open install guide'),
                onTap: () => context.push('/install-guide'),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(tr('Install guide'),
                        style: UtText.caption.copyWith(color: UtColors.text)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward,
                        size: 12, color: UtColors.text),
                  ]),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _SharedRow extends StatelessWidget {
  const _SharedRow(
      {required this.title, required this.detail, required this.shared});

  final String title;
  final String detail;
  final bool shared;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: UtText.bodyStrong),
            const SizedBox(height: 2),
            Text(detail, style: UtText.caption),
          ],
        ),
      ),
      SizedBox(
        width: 30,
        child: shared
            ? const Icon(Icons.check,
                size: 16, color: UtColors.green, semanticLabel: 'Shared')
            : Text('—',
                textAlign: TextAlign.center,
                semanticsLabel: tr('Not shared'),
                style: UtText.bodyStrong),
      ),
    ]);
  }
}

/// M03 — Install guide.
class InstallGuideScreen extends StatelessWidget {
  const InstallGuideScreen({super.key});

  static const _steps = [
    ('Download desktop app', 'Linux, macOS and Windows'),
    ('Sign in with Google', 'Use the same account as mobile'),
    ('Sign in on this phone', 'Continue with the same Google account'),
    ('Leave it running', 'Usage syncs in the background'),
  ];

  @override
  Widget build(BuildContext context) {
    return UtPage(
      title: tr('Install μToken Companion'),
      subtitle: tr('Set up automatic tracking on your computer.'),
      onBack: () => _back(context, '/connect-desktop'),
      actions: [
        UtButton(
            label: tr('Download desktop app'),
            onPressed: () => showDialog<void>(
                context: context,
                builder: (dialog) => AlertDialog(
                      title: Text(tr('Install on your computer')),
                      content: Text(tr(
                          'Install μToken Companion on Linux, macOS or Windows, open it and choose Sign in with Google. Use the same account as this phone, then press Sync now.')),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(dialog),
                            child: Text(tr('OK'))),
                      ],
                    ))),
        UtButton(
            label: tr('I already installed it'),
            actionName: 'Already installed',
            style: UtButtonStyle.secondary,
            onPressed: () => _back(context, '/connect-desktop')),
      ],
      children: [
        UtCard(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
          child: Column(
            children: [
              for (var i = 0; i < _steps.length; i++)
                _Step(
                  number: i + 1,
                  title: _steps[i].$1,
                  detail: _steps[i].$2,
                  last: i == _steps.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(
      {required this.number,
      required this.title,
      required this.detail,
      required this.last});

  final int number;
  final String title;
  final String detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: UtColors.chip,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: UtColors.cardBorder),
                ),
                child: Text(number.toString().padLeft(2, '0'),
                    style: UtText.caption.copyWith(color: UtColors.text)),
              ),
              if (!last)
                const Expanded(
                    child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                      width: 1, child: ColoredBox(color: UtColors.cardBorder)),
                )),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: UtText.bodyStrong),
                  const SizedBox(height: 4),
                  Text(detail, style: UtText.caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
