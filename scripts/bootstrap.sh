#!/usr/bin/env bash
# Genera la parte Android del progetto, installa le dipendenze, configura
# asset e icona. Idempotente: si può rilanciare.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v flutter >/dev/null || { echo "Flutter non trovato nel PATH"; exit 1; }

if [ ! -d android ]; then
  TMP="$(mktemp -d)"
  cp -r lib "$TMP/lib"
  cp -r assets "$TMP/assets"
  flutter create . --org com.dvdsalviato --project-name ukeep --platforms android
  rm -rf lib && cp -r "$TMP/lib" lib
  rm -rf assets && cp -r "$TMP/assets" assets
  rm -f test/widget_test.dart
fi

flutter pub add flutter_localizations --sdk=flutter
flutter pub add firebase_core firebase_auth cloud_firestore google_sign_in flutter_riverpod intl
flutter pub add --dev flutter_launcher_icons

python3 scripts/patch_pubspec.py
flutter pub get
dart run flutter_launcher_icons

# Nome dell'app sotto l'icona
sed -i 's/android:label="[^"]*"/android:label="Ukeep"/' android/app/src/main/AndroidManifest.xml

echo "Fatto."
