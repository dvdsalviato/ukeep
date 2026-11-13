import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';
import 'couple_service.dart';

final authServiceProvider = Provider((ref) => AuthService());
final coupleServiceProvider = Provider((ref) => CoupleService());

final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

final coupleIdProvider = StreamProvider<String?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(coupleServiceProvider).watchCoupleId(user.uid);
});
