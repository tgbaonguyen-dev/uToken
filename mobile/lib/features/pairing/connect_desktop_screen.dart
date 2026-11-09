import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../auth/domain/mobile_auth.dart';
import 'firebase_pairing.dart';

class ConnectDesktopScreen extends StatefulWidget {
  const ConnectDesktopScreen(
      {super.key,
      required this.gateway,
      this.informationOnly = false,
      this.waitingForUsage = false});
  final MobilePairingGateway gateway;
  final bool informationOnly;
  final bool waitingForUsage;
  @override
  State<ConnectDesktopScreen> createState() => _ConnectDesktopScreenState();
}

class _ConnectDesktopScreenState extends State<ConnectDesktopScreen> {
  StreamSubscription<DevicePairing?>? _subscription;
  Timer? _timer;
  DevicePairing? _pairing;
  bool _busy = false;
  bool _confirmed = false;
  bool _received = false;
  String? _error;
  bool _sawPending = false;
  String? _lastCode;
  int _waitingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _listen();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _waitingSeconds++;
        });
      }
    });
    if (!widget.informationOnly) _run(() => widget.gateway.create());
  }

  void _listen() {
    _subscription = widget.gateway.watch().listen((value) {
      if (!mounted) return;
      setState(() {
        if (value?.code != _lastCode) {
          _lastCode = value?.code;
          _waitingSeconds = 0;
        }
        if (value != null && !value.paired && !value.inactive) {
          _sawPending = true;
        }
        _pairing = value;
        _received = true;
        _confirmed = true;
        _error = null;
      });
      if (value?.paired == true && _sawPending && !widget.informationOnly) {
        MobileAuthScope.maybeOf(context)?.leaveDesktopSetup();
        context.go('/waiting-first-usage');
      }
    }, onError: (Object _) {
      if (mounted) {
        setState(() {
          _confirmed = false;
          _error =
              'Could not verify pairing. Check your connection and Firebase pairing rules, then retry.';
        });
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action().timeout(const Duration(seconds: 25));
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Pairing request did not complete. Check your connection, sign-in and Firestore rules.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _leave() {
    MobileAuthScope.maybeOf(context)?.leaveDesktopSetup();
    context.go(widget.informationOnly ? '/settings' : '/tokens');
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paired = _confirmed && _pairing?.paired == true;
    final remaining =
        _pairing?.expiresAt.difference(DateTime.now()).inSeconds ?? 0;
    final valid = _confirmed &&
        _pairing != null &&
        !_pairing!.inactive &&
        !paired &&
        remaining > 0;
    final noResponse = valid && _waitingSeconds >= 30;
    final code = _pairing?.code ?? '------';
    final account =
        MobileAuthScope.maybeOf(context)?.user?.email ?? 'your Google account';
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: Scaffold(
            backgroundColor: const Color(0xff080a0b),
            appBar: AppBar(
                backgroundColor: const Color(0xff080a0b),
                leading: IconButton(
                    onPressed: _leave,
                    icon: const Icon(Icons.arrow_back_ios_new)),
                title: Text(widget.waitingForUsage
                    ? 'Waiting for first usage'
                    : widget.informationOnly
                        ? 'Desktop connection'
                        : 'Connect desktop')),
            body: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child:
                        ListView(padding: const EdgeInsets.all(24), children: [
                      Text(
                          'Use the same Google account on both devices: $account',
                          style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 28),
                      Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              color: const Color(0xff111416),
                              border:
                                  Border.all(color: const Color(0xff292d32)),
                              borderRadius: BorderRadius.circular(20)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                    paired
                                        ? 'CONNECTED DESKTOP'
                                        : 'PAIRING CODE',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                                const SizedBox(height: 28),
                                Text(
                                    paired
                                        ? _pairing!.desktopName!
                                        : valid
                                            ? '${code.substring(0, 3)} — ${code.substring(3)}'
                                            : '— — —',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                Text(
                                    paired
                                        ? (!widget.informationOnly &&
                                                !_sawPending
                                            ? 'Existing desktop - disconnect it before pairing another'
                                            : 'Paired successfully')
                                        : valid
                                            ? 'Expires in ${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}'
                                            : _received
                                                ? (_pairing == null
                                                    ? 'No desktop connected'
                                                    : _pairing?.state ==
                                                            'revoked'
                                                        ? 'Connection revoked - history retained'
                                                        : _pairing?.state ==
                                                                'cancelled'
                                                            ? 'Pairing cancelled'
                                                            : 'PAIRING_EXPIRED: Generate a new code')
                                                : 'Connecting to Firebase…',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: paired
                                            ? const Color(0xff2ec790)
                                            : Colors.orange)),
                                const SizedBox(height: 20),
                                if (noResponse) ...[
                                  const Text(
                                      'Desktop no response. Open the desktop app, sign in with the same Google account and enter this code.'),
                                  OutlinedButton(
                                      onPressed: _busy
                                          ? null
                                          : () async {
                                              setState(() {
                                                _waitingSeconds = 0;
                                              });
                                              await _run(() =>
                                                  widget.gateway.create());
                                            },
                                      child: const Text(
                                          'Retry desktop connection')),
                                ],
                                if (paired &&
                                    (!widget.informationOnly ||
                                        widget.waitingForUsage))
                                  OutlinedButton(
                                      onPressed: () =>
                                          context.go('/desktop-connection'),
                                      child: const Text('View connection')),
                                if (valid)
                                  OutlinedButton(
                                      onPressed: () async {
                                        await Clipboard.setData(
                                            ClipboardData(text: code));
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      'Pairing code copied.')));
                                        }
                                      },
                                      child: const Text('Copy code')),
                                if (!paired)
                                  OutlinedButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _run(() => widget.gateway
                                              .create(renew: true)),
                                      child: const Text('Generate new code')),
                                if (valid)
                                  TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () async {
                                              await _run(widget.gateway.cancel);
                                              if (mounted && _error == null) {
                                                _leave();
                                              }
                                            },
                                      child: const Text('Cancel pairing')),
                                const Divider(height: 40),
                                const Text(
                                    'Only the device association is saved. Usage sync is not enabled. Prompt content is not uploaded.'),
                                if (paired) ...[
                                  const SizedBox(height: 20),
                                  OutlinedButton(
                                      onPressed: _busy
                                          ? null
                                          : () async {
                                              final confirmed = await showDialog<
                                                      bool>(
                                                  context: context,
                                                  builder: (context) =>
                                                      AlertDialog(
                                                          title: const Text(
                                                              'Disconnect desktop?'),
                                                          content: const Text(
                                                              'You will need a new code to pair again.'),
                                                          actions: [
                                                            TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        context,
                                                                        false),
                                                                child: const Text(
                                                                    'Cancel')),
                                                            TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        context,
                                                                        true),
                                                                child: const Text(
                                                                    'Disconnect'))
                                                          ]));
                                              if (confirmed == true &&
                                                  mounted) {
                                                await _run(
                                                    widget.gateway.disconnect);
                                              }
                                            },
                                      child: const Text('Disconnect desktop')),
                                ],
                              ])),
                      if (_busy)
                        const Padding(
                            padding: EdgeInsets.all(20),
                            child: LinearProgressIndicator()),
                      if (_error != null) ...[
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(_error!,
                                style:
                                    const TextStyle(color: Colors.redAccent))),
                        OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () async {
                                    await _subscription?.cancel();
                                    if (!mounted) return;
                                    _listen();
                                    if (!widget.informationOnly) {
                                      await _run(() => widget.gateway.create());
                                    }
                                  },
                            child: const Text('Retry')),
                      ],
                      const SizedBox(height: 28),
                      if (!paired && widget.informationOnly)
                        FilledButton(
                            onPressed: () => context.go('/connect-desktop'),
                            child: const Text('Connect desktop')),
                      if (!paired && !widget.informationOnly)
                        TextButton(
                            onPressed: () => context.push('/install-guide'),
                            child: const Text('Install desktop app')),
                      if (!paired && !widget.informationOnly)
                        const Text(
                            'Enter this code in the desktop app → Sync → Pair new device. This screen updates automatically after confirmation.'),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: () {
                            MobileAuthScope.maybeOf(context)
                                ?.leaveDesktopSetup();
                            context.go('/tokens');
                          },
                          child: Text(
                              paired ? 'Continue to Tokens' : 'Skip for now')),
                    ])))));
  }
}
