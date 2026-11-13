import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'theme.dart';
import 'ui.dart';

/// Cambia la foto profilo: la immagine (piccola) viene salvata nel
/// documento utente su Firestore, senza bisogno di altri servizi.
Future<void> changeProfilePhoto(BuildContext context) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  final choice = await showUSheet<String>(
    context,
    Builder(
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Foto profilo', style: serif(28)),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Scegli dalla galleria'),
            onTap: () => Navigator.pop(ctx, 'gallery'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Scatta una foto'),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_outline, color: UColors.danger),
            title: const Text('Rimuovi foto',
                style: TextStyle(color: UColors.danger)),
            onTap: () => Navigator.pop(ctx, 'remove'),
          ),
        ],
      ),
    ),
  );
  if (choice == null) return;
  final ref = FirebaseFirestore.instance.collection('users').doc(uid);
  if (choice == 'remove') {
    ref.set({'photoB64': FieldValue.delete()}, SetOptions(merge: true));
    return;
  }
  try {
    final x = await ImagePicker().pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 75,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    ref.set({'photoB64': base64Encode(bytes)}, SetOptions(merge: true));
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Foto non caricata: $e')));
    }
  }
}
