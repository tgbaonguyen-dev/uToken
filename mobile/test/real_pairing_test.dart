import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:utoken_mobile/features/pairing/firebase_pairing.dart';
import 'package:utoken_mobile/features/pairing/connect_desktop_screen.dart';

class PairingFake implements MobilePairingGateway {
  final changes = StreamController<DevicePairing?>.broadcast();
  int creates = 0;
  bool fail = false;
  @override
  Stream<DevicePairing?> watch() => changes.stream;
  @override
  Future<void> create({bool renew = false}) async {
    creates++;
    if (fail) throw StateError('offline');
  }

  @override
  Future<void> disconnect() async => changes.add(null);
  @override
  Future<void> cancel() async => changes.add(null);
}

void main() {
  testWidgets('a missing connection is not incorrectly labelled expired',
      (tester) async {
    final gateway = PairingFake();
    await tester.pumpWidget(MaterialApp(
        home: ConnectDesktopScreen(gateway: gateway, informationOnly: true)));
    gateway.changes.add(null);
    await tester.pumpAndSettle();
    expect(find.text('No desktop connected'), findsOneWidget);
    expect(find.textContaining('PAIRING_EXPIRED'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await gateway.changes.close();
  });
  test('generated codes use the unambiguous SRS alphabet', () {
    final random = Random(42);
    for (var i = 0; i < 1000; i++) {
      final code = generatePairingCode(random);
      expect(RegExp(r'^[A-HJ-NP-Z2-9]{6}$').hasMatch(code), isTrue);
    }
  });
  test('revoked association is not connected even if it has a desktop name',
      () {
    final value =
        DevicePairing('AB2CD3', DateTime(2026), 'Old PC', state: 'revoked');
    expect(value.paired, isFalse);
    expect(value.inactive, isTrue);
  });
  testWidgets('existing desktop is shown instead of fabricating a new pairing',
      (tester) async {
    final gateway = PairingFake();
    await tester
        .pumpWidget(MaterialApp(home: ConnectDesktopScreen(gateway: gateway)));
    await tester.pump();
    gateway.changes.add(DevicePairing(
        'AB2CD3', DateTime.now(), 'Existing Windows PC',
        state: 'paired'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Existing desktop - disconnect'), findsOneWidget);
    expect(find.text('Disconnect desktop'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await gateway.changes.close();
  });
  testWidgets('no desktop response appears after thirty seconds with retry',
      (tester) async {
    final gateway = PairingFake();
    await tester
        .pumpWidget(MaterialApp(home: ConnectDesktopScreen(gateway: gateway)));
    await tester.pump();
    gateway.changes.add(DevicePairing(
        'AB2CD3', DateTime.now().add(const Duration(minutes: 5)), null));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    expect(find.textContaining('Desktop no response.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Retry desktop connection'), 200);
    await tester.tap(find.text('Retry desktop connection'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Desktop no response.'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await gateway.changes.close();
  });
  test('expiry never marks a pending request as paired', () {
    final request = DevicePairing('000123', DateTime(2026), null);
    expect(request.expired(DateTime(2027)), isTrue);
    expect(request.paired, isFalse);
  });
  testWidgets(
      'waits for server confirmation, then opens connection information',
      (tester) async {
    final gateway = PairingFake();
    final router = GoRouter(initialLocation: '/connect', routes: [
      GoRoute(
          path: '/connect',
          builder: (_, __) => ConnectDesktopScreen(gateway: gateway)),
      GoRoute(
          path: '/waiting-first-usage',
          builder: (_, __) =>
              const Scaffold(body: Text('Server confirmed desktop'))),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    gateway.changes.add(DevicePairing(
        '123456', DateTime.now().add(const Duration(minutes: 5)), null));
    await tester.pumpAndSettle();
    expect(find.text('123 — 456'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/connect');
    expect(find.text('I’ve paired my device'), findsNothing);
    gateway.changes.add(DevicePairing('123456', DateTime.now(), 'Windows PC'));
    await tester.pumpAndSettle();
    expect(find.text('Server confirmed desktop'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    await gateway.changes.close();
  });
  testWidgets(
      'failed create offers retry and cannot fabricate successful pairing',
      (tester) async {
    final gateway = PairingFake()..fail = true;
    await tester
        .pumpWidget(MaterialApp(home: ConnectDesktopScreen(gateway: gateway)));
    await tester.pumpAndSettle();
    expect(find.textContaining('request did not complete'), findsOneWidget);
    expect(find.text('Paired successfully'), findsNothing);
    gateway.fail = false;
    await tester.scrollUntilVisible(find.text('Retry'), 200);
    await tester.runAsync(() async {
      await tester.tap(find.text('Retry'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(gateway.creates, 2);
    await tester.pumpWidget(const SizedBox());
    await gateway.changes.close();
  });
}
