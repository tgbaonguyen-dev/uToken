import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../features/auth/data/firebase_auth_repository.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/presentation/auth_controller.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  const clientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  return FirebaseAuthRepository(
      FirebaseAuth.instance,
      GoogleSignIn(
          scopes: ['email', 'profile'],
          serverClientId: clientId.isEmpty ? null : clientId));
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.watch(authRepositoryProvider)),
);

// Feature repositories must use this UID-scoped reference, never a hard-coded user.
final userDocumentProvider =
    Provider<DocumentReference<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) throw StateError('AUTH_INVALID');
  return FirebaseFirestore.instance.collection('users').doc(user.uid);
});
