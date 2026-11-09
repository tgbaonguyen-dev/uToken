import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const pairingAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
String generatePairingCode([Random? random]) {
  final rng = random ?? Random.secure();
  return List.generate(
      6, (_) => pairingAlphabet[rng.nextInt(pairingAlphabet.length)]).join();
}

String _connectionId() {
  final rng = Random.secure();
  final bytes = List.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class DevicePairing {
  const DevicePairing(this.code, this.expiresAt, this.desktopName,
      {this.state = 'pending', this.connectionId});
  final String code;
  final DateTime expiresAt;
  final String? desktopName;
  final String state;
  final String? connectionId;
  bool get paired =>
      desktopName != null && state != 'revoked' && state != 'cancelled';
  bool get inactive => state == 'revoked' || state == 'cancelled';
  bool expired(DateTime now) => !paired && !expiresAt.isAfter(now);
  factory DevicePairing.fromMap(Map<String, dynamic> data) => DevicePairing(
      data['code'] as String,
      (data['createdAt'] as Timestamp)
          .toDate()
          .add(const Duration(minutes: 10)),
      data['state'] == 'paired' ? data['desktopName'] as String : null,
      state: data['state'] as String,
      connectionId: data['connectionId'] as String);
}

abstract interface class MobilePairingGateway {
  Stream<DevicePairing?> watch();
  Future<void> create({bool renew = false});
  Future<void> disconnect();
  Future<void> cancel();
}

class FirebaseMobilePairing implements MobilePairingGateway {
  FirebaseMobilePairing(
      {FirebaseFirestore? firestore, FirebaseAuth? auth, this.onSessionExpired})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final Future<void> Function()? onSessionExpired;
  DocumentReference<Map<String, dynamic>> get _document {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Session expired. Sign in again.');
    return _db.doc('users/${user.uid}/pairing/current');
  }

  Future<void> _checkSession(Object error) async {
    if (error is FirebaseException &&
        const ['permission-denied', 'unauthenticated'].contains(error.code)) {
      try {
        await _auth.currentUser?.getIdToken(true);
      } on FirebaseAuthException catch (authError) {
        if (const [
          'user-token-expired',
          'invalid-user-token',
          'user-disabled',
          'user-not-found'
        ].contains(authError.code)) {
          await onSessionExpired?.call();
        }
      }
    }
  }

  @override
  Stream<DevicePairing?> watch() async* {
    try {
      await for (final event
          in _document.snapshots(includeMetadataChanges: true)) {
        if (!event.metadata.hasPendingWrites && !event.metadata.isFromCache) {
          yield event.exists ? DevicePairing.fromMap(event.data()!) : null;
        }
      }
    } catch (error) {
      await _checkSession(error);
      rethrow;
    }
  }

  @override
  Future<void> create({bool renew = false}) async {
    final ref = _document;
    final code = generatePairingCode();
    final id = _connectionId();
    try {
      await _db.runTransaction((tx) async {
        final current = await tx.get(ref);
        if (current.exists) {
          final existing = DevicePairing.fromMap(current.data()!);
          if (existing.paired ||
              (!renew &&
                  !existing.inactive &&
                  !existing.expired(DateTime.now()))) {
            return;
          }
        }
        tx.set(ref, {
          'schemaVersion': 2,
          'state': 'pending',
          'code': code,
          'connectionId': id,
          'mobileName': 'Android phone',
          'desktopName': '',
          'desktopId': '',
          'createdAt': FieldValue.serverTimestamp(),
          'pairedAt': null,
          'revokedAt': null,
          'cancelledAt': null,
        });
      }, timeout: const Duration(seconds: 20));
    } catch (error) {
      await _checkSession(error);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    final ref = _document;
    try {
      await _db.runTransaction((tx) async {
        final current = await tx.get(ref);
        if (!current.exists || current.data()!['state'] != 'paired') return;
        final data = {
          ...current.data()!,
          'state': 'revoked',
          'revokedAt': FieldValue.serverTimestamp()
        };
        tx.set(ref, data);
        tx.set(
            _db.doc(
                'users/${_auth.currentUser!.uid}/connections/${data['connectionId']}'),
            data);
      }, timeout: const Duration(seconds: 20));
    } catch (error) {
      await _checkSession(error);
      rethrow;
    }
  }

  @override
  Future<void> cancel() async {
    final ref = _document;
    try {
      await _db.runTransaction((tx) async {
        final current = await tx.get(ref);
        if (current.exists && current.data()!['state'] == 'pending') {
          tx.update(ref, {
            'state': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp()
          });
        }
      }, timeout: const Duration(seconds: 20));
    } catch (error) {
      await _checkSession(error);
      rethrow;
    }
  }
}
