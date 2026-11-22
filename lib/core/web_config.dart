import 'package:firebase_core/firebase_core.dart';

/// Configurazione Firebase della webapp. I valori arrivano durante la build
/// web (GitHub Actions, secret FIREBASE_WEB_CONFIG) con --dart-define.
/// Sul telefono non servono: lì si usa google-services.json.
const webFirebaseOptions = FirebaseOptions(
  apiKey: String.fromEnvironment('FB_API_KEY'),
  appId: String.fromEnvironment('FB_APP_ID'),
  messagingSenderId:
      String.fromEnvironment('FB_SENDER_ID', defaultValue: '550170162235'),
  projectId: String.fromEnvironment('FB_PROJECT_ID', defaultValue: 'ukeep-e1f0e'),
  authDomain: String.fromEnvironment('FB_AUTH_DOMAIN',
      defaultValue: 'ukeep-e1f0e.firebaseapp.com'),
  storageBucket: String.fromEnvironment('FB_STORAGE_BUCKET',
      defaultValue: 'ukeep-e1f0e.firebasestorage.app'),
);

bool get webConfigured =>
    webFirebaseOptions.apiKey.isNotEmpty && webFirebaseOptions.appId.isNotEmpty;
