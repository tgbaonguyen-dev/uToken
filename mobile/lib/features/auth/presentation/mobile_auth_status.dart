import 'package:flutter/material.dart';

import '../../../core/i18n/tr.dart';
import '../../../core/ui/ut_kit.dart';
import '../domain/mobile_auth.dart';

/// Sign-in progress and errors over the auth screens.
///
/// Errors sit at the top, under the status bar, so they never cover the
/// "Continue with Google" button the user needs to retry.
class MobileAuthStatus extends StatelessWidget {
  const MobileAuthStatus({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = MobileAuthScope.maybeOf(context);
    if (auth == null) return child;
    if (auth.demoMode) return child;
    return PopScope(
        canPop: !auth.busy,
        child: Stack(fit: StackFit.expand, children: [
          AbsorbPointer(absorbing: auth.busy, child: child),
          Positioned(
            left: 16,
            right: 16,
            top: 0,
            child: SafeArea(
              child: AnimatedSwitcher(
                duration: UtMotion.medium,
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                      position:
                          Tween(begin: const Offset(0, -0.3), end: Offset.zero)
                              .animate(a),
                      child: c),
                ),
                child: auth.message == null
                    ? const SizedBox.shrink()
                    : Padding(
                        key: ValueKey(auth.message),
                        padding: const EdgeInsets.only(top: 8),
                        child: Material(
                          color: UtColors.card,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                  color:
                                      UtColors.orange.withValues(alpha: 0.5))),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
                            child: Row(children: [
                              const Icon(Icons.error_outline_rounded,
                                  size: 18, color: UtColors.orange),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(tr(auth.message!),
                                      key: const ValueKey('auth-message'),
                                      style: UtText.bodyStrong)),
                              IconButton(
                                  tooltip: tr('Dismiss message'),
                                  onPressed: auth.dismissMessage,
                                  icon: const Icon(Icons.close_rounded,
                                      size: 18, color: UtColors.muted)),
                            ]),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          if (auth.busy) ...[
            const ModalBarrier(dismissible: false, color: Colors.black54),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                decoration: BoxDecoration(
                    color: UtColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: UtColors.cardBorder)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(
                      color: UtColors.text,
                      semanticsLabel: tr('Updating account')),
                  const SizedBox(height: 16),
                  Text(tr('Please wait…'), style: UtText.bodyStrong),
                ]),
              ),
            ),
          ],
        ]));
  }
}
