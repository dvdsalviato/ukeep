import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';
import 'couple_service.dart';
import 'repo.dart';

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

final repoProvider = Provider<Repo?>((ref) {
  final id = ref.watch(coupleIdProvider).value;
  return id == null ? null : Repo(id);
});

StreamProvider<List<Item>> _collection(String name) =>
    StreamProvider<List<Item>>((ref) {
      final repo = ref.watch(repoProvider);
      if (repo == null) return Stream.value(<Item>[]);
      return repo.watch(name);
    });

final tasksProvider = _collection('tasks');
final listsProvider = _collection('lists');
final wishesProvider = _collection('wishes');
final eventsProvider = _collection('events');
final projectsProvider = _collection('projects');
final expensesProvider = _collection('expenses');
final pollsProvider = _collection('polls');
final memoriesProvider = _collection('memories');

/// L'ultimo abbraccio mandato (da uno dei due).
final lastHugProvider = StreamProvider<Item?>((ref) {
  final repo = ref.watch(repoProvider);
  if (repo == null) return Stream.value(null);
  return repo
      .col('hugs')
      .orderBy('at', descending: true)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty
          ? null
          : Item(s.docs.first.id, s.docs.first.data()));
});

/// I due profili (nome, foto) dello spazio condiviso.
final membersProvider = StreamProvider<List<Item>>((ref) {
  final repo = ref.watch(repoProvider);
  if (repo == null) return Stream.value(<Item>[]);
  return repo.watchMembers();
});

/// Il documento couples/{id} (inviteCode, since, members...).
final coupleDocProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final id = ref.watch(coupleIdProvider).value;
  if (id == null) return Stream.value(null);
  return ref.watch(coupleServiceProvider).watchCouple(id);
});
