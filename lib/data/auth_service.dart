import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'couple_service.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;

  Future<void> signInWithGoogle() async {
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }

  /// Elimina l'account: prima riconferma l'accesso Google (lo chiede
  /// Firebase), poi esce dalla coppia, cancella il profilo e l'account.
  Future<void> deleteAccount(String? coupleId) async {
    final u = _auth.currentUser;
    if (u == null) return;
    final account = await GoogleSignIn.instance.authenticate();
    final cred =
        GoogleAuthProvider.credential(idToken: account.authentication.idToken);
    await u.reauthenticateWithCredential(cred);
    if (coupleId != null) await CoupleService().leaveCouple(u.uid, coupleId);
    await FirebaseFirestore.instance.collection('users').doc(u.uid).delete();
    await u.delete();
    await GoogleSignIn.instance.signOut();
  }
}
