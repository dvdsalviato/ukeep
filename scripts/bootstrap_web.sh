#!/usr/bin/env bash
# Genera la parte web del progetto (webapp) e installa le dipendenze.
# Le dipendenze sono le stesse di scripts/bootstrap.sh: se ne aggiungi
# una lì, aggiungila anche qui.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v flutter >/dev/null || { echo "Flutter non trovato nel PATH"; exit 1; }

# la chiave delle push NON deve mai finire nel sito pubblico
rm -f assets/fcm_sa.json

if [ ! -d web ]; then
  TMP="$(mktemp -d)"
  cp -r lib "$TMP/lib"
  cp -r assets "$TMP/assets"
  flutter create . --org com.dvdsalviato --project-name ukeep --platforms web
  rm -rf lib && cp -r "$TMP/lib" lib
  rm -rf assets && cp -r "$TMP/assets" assets
  rm -f test/widget_test.dart
fi

flutter pub add flutter_localizations --sdk=flutter
flutter pub add firebase_core firebase_auth cloud_firestore google_sign_in flutter_riverpod intl image_picker image shared_preferences crypto
flutter pub add flutter_local_notifications:^19.5.0 timezone:^0.10.0
flutter pub add firebase_messaging googleapis_auth home_widget
flutter pub add package_info_plus url_launcher http
flutter pub add local_auth:^2.3.0
flutter pub add permission_handler:^11.4.0

python3 scripts/patch_pubspec.py
python3 scripts/patch_web.py
flutter pub get

echo "Fatto (web)."
