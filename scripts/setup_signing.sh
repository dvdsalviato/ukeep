#!/usr/bin/env bash
# Crea (una sola volta) il keystore e configura Gradle per usarlo sempre.
set -euo pipefail
cd "$(dirname "$0")/.."

KS_DIR="$HOME/.ukeep"
KS="$KS_DIR/ukeep-release.jks"
ALIAS="ukeep"
mkdir -p "$KS_DIR"

KEYTOOL="keytool"
command -v keytool >/dev/null || KEYTOOL="${JAVA_HOME:-}/bin/keytool"

read -rsp "Password del keystore (min 6 caratteri, salvala!): " PW; echo

if [ ! -f "$KS" ]; then
  "$KEYTOOL" -genkeypair -v -keystore "$KS" -alias "$ALIAS" \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass "$PW" -keypass "$PW" -dname "CN=ukeep, C=IT"
else
  echo "Keystore già presente: $KS (riuso quello)"
fi

KS_PATH="$KS"
command -v cygpath >/dev/null && KS_PATH="$(cygpath -m "$KS")"

cat > android/key.properties <<PROP
storePassword=$PW
keyPassword=$PW
keyAlias=$ALIAS
storeFile=$KS_PATH
PROP

PY=python3; command -v python3 >/dev/null || PY=python
"$PY" scripts/patch_gradle.py

echo
echo "=== Aggiungi queste impronte in Firebase (Impostazioni progetto > la tua app Android) ==="
"$KEYTOOL" -list -v -keystore "$KS" -alias "$ALIAS" -storepass "$PW" | grep -E "SHA1|SHA256"
echo
echo "FAI UN BACKUP di $KS e della password: senza, non potrai più aggiornare l'app."
