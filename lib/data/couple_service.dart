import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Gestisce lo "spazio condiviso" tra i due account.
/// users/{uid}            -> { coupleId, name, photo, email }
/// couples/{coupleId}     -> { members: [uid, uid], inviteCode }
/// invites/{code}         -> { coupleId }
/// couples/{id}/...       -> tutti i dati condivisi (attività, liste, ecc.)
class CoupleService {
  final _db = FirebaseFirestore.instance;

  Stream<String?> watchCoupleId(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((s) => s.data()?['coupleId'] as String?);

  Stream<Map<String, dynamic>?> watchCouple(String coupleId) =>
      _db.collection('couples').doc(coupleId).snapshots().map((s) => s.data());

  Map<String, dynamic> _profile(User u, String coupleId) => {
        'coupleId': coupleId,
        'name': u.displayName,
        'photo': u.photoURL,
        'email': u.email,
      };

  Future<void> createCouple(User user) async {
    final ref = _db.collection('couples').doc();
    final code = _randomCode();
    final batch = _db.batch();
    batch.set(ref, {
      'members': [user.uid],
      'inviteCode': code,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_db.collection('invites').doc(code), {'coupleId': ref.id});
    batch.set(_db.collection('users').doc(user.uid), _profile(user, ref.id),
        SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> joinCouple(User user, String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    final invite = await _db.collection('invites').doc(code).get();
    if (!invite.exists) throw 'Codice non valido';
    final coupleId = invite.data()!['coupleId'] as String;
    final batch = _db.batch();
    batch.update(_db.collection('couples').doc(coupleId), {
      'members': FieldValue.arrayUnion([user.uid]),
    });
    batch.set(_db.collection('users').doc(user.uid), _profile(user, coupleId),
        SetOptions(merge: true));
    await batch.commit();
  }

  /// Esce dalla coppia: i dati condivisi restano al partner.
  Future<void> leaveCouple(String uid, String coupleId) async {
    final batch = _db.batch();
    batch.update(_db.collection('couples').doc(coupleId), {
      'members': FieldValue.arrayRemove([uid]),
    });
    batch.update(_db.collection('users').doc(uid), {
      'coupleId': FieldValue.delete(),
    });
    await batch.commit();
  }

  String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
