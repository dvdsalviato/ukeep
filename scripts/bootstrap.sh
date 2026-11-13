#!/usr/bin/env bash
# Genera la parte Android del progetto e installa le dipendenze.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v flutter >/dev/null || { echo "Flutter non trovato nel PATH"; exit 1; }

if [ ! -d android ]; then
  TMP="$(mktemp -d)"
  cp -r lib "$TMP/lib"
  flutter create . --org com.dvdsalviato --project-name ukeep --platforms android
  rm -rf lib && cp -r "$TMP/lib" lib
  rm -f test/widget_test.dart
fi

flutter pub add firebase_core firebase_auth cloud_firestore google_sign_in flutter_riverpod intl
echo "Fatto."
