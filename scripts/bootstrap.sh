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
flutter pub add firebase_core firebase_auth cloud_firestore google_sign_in flutter_riverpod intl image_picker image shared_preferences crypto
flutter pub add flutter_local_notifications:^19.5.0 timezone:^0.10.0
flutter pub add firebase_messaging googleapis_auth home_widget
flutter pub add package_info_plus url_launcher http
flutter pub add --dev flutter_launcher_icons

python3 scripts/patch_pubspec.py
flutter pub get
dart run flutter_launcher_icons

# Icona piccola (monocromatica) per le notifiche
mkdir -p android/app/src/main/res/drawable
cp assets/ic_stat.png android/app/src/main/res/drawable/ic_stat.png
# evita che la riduzione risorse elimini l'icona (usata solo per nome)
mkdir -p android/app/src/main/res/raw
cat > android/app/src/main/res/raw/keep.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@drawable/ic_stat" />
XML

# Widget Home (Kotlin, layout) e risorse extra
cp -r scripts/android_extra/. android/app/src/main/

# Permessi, ricevitori notifiche, widget, push e desugaring
python3 scripts/patch_android.py

# Nome dell'app sotto l'icona
sed -i 's/android:label="[^"]*"/android:label="Ukeep"/' android/app/src/main/AndroidManifest.xml

echo "Fatto."
