import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Un documento Firestore con il suo id.
class Item {
  Item(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;

  String str(String k, [String d = '']) => (data[k] as String?) ?? d;
  bool flag(String k) => data[k] == true;

  DateTime? date(String k) {
    final v = data[k];
    return v is Timestamp ? v.toDate() : null;
  }

  List<Map<String, dynamic>> steps(String k) {
    final v = data[k];
    if (v is! List) return [];
    return v
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: true);
  }
}

/// Accesso ai dati condivisi: couples/{coupleId}/{collezione}/{id}
class Repo {
  Repo(this.coupleId);
  final String coupleId;
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> col(String name) =>
      _db.collection('couples').doc(coupleId).collection(name);

  Stream<List<Item>> watch(String name) => col(name)
      .snapshots()
      .map((s) => s.docs.map((d) => Item(d.id, d.data())).toList());

  Stream<List<Item>> watchMembers() => _db
      .collection('users')
      .where('coupleId', isEqualTo: coupleId)
      .snapshots()
      .map((s) => s.docs.map((d) => Item(d.id, d.data())).toList());

  Future<void> add(String name, Map<String, dynamic> data) => col(name).add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'by': FirebaseAuth.instance.currentUser?.uid,
      });

  Future<void> update(String name, String id, Map<String, dynamic> data) =>
      col(name).doc(id).update(data);

  Future<void> remove(String name, String id) => col(name).doc(id).delete();

  Future<void> setSince(DateTime d) => _db
      .collection('couples')
      .doc(coupleId)
      .update({'since': Timestamp.fromDate(d)});
}
