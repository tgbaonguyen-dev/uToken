import 'package:flutter/material.dart';

import '../domain/mobile_auth.dart';

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
          if (auth.message != null)
            Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: SafeArea(
                    child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                            child: Row(children: [
                              Expanded(
                                  child: Text(auth.message!,
                                      key: const ValueKey('auth-message'),
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onErrorContainer))),
                              IconButton(
                                  tooltip: 'Dismiss message',
                                  onPressed: auth.dismissMessage,
                                  icon: const Icon(Icons.close)),
                            ]))))),
          if (auth.busy) ...[
            const ModalBarrier(dismissible: false, color: Colors.black54),
            const Center(
                child: Card(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          CircularProgressIndicator(
                              semanticsLabel: 'Updating account'),
                          SizedBox(height: 16),
                          Text('Please wait…'),
                        ])))),
          ],
        ]));
  }
}
