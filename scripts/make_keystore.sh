#!/usr/bin/env bash
# Da eseguire UNA volta (es. in Termux). Crea il keystore fisso dell'app.
set -euo pipefail
KS_DIR="$HOME/.ukeep"
KS="$KS_DIR/ukeep-release.jks"
mkdir -p "$KS_DIR"

read -rsp "Scegli una password (min 6 caratteri, ricordala): " PW; echo

if [ ! -f "$KS" ]; then
  keytool -genkeypair -keystore "$KS" -alias ukeep \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass "$PW" -keypass "$PW" -dname "CN=ukeep, C=IT"
fi

OUT="$HOME/storage/downloads"
[ -d "$OUT" ] || OUT="$HOME"
base64 -w0 "$KS" > "$OUT/ukeep-keystore-base64.txt"
cp "$KS" "$OUT/ukeep-release-BACKUP.jks"

echo
echo "== Impronte da mettere in Firebase =="
keytool -list -v -keystore "$KS" -alias ukeep -storepass "$PW" | grep -E "SHA1|SHA256"
echo
echo "Creati in $OUT:"
echo " - ukeep-keystore-base64.txt  (il testo va nel secret KEYSTORE_B64 su GitHub)"
echo " - ukeep-release-BACKUP.jks   (backup: conservalo, poi NON metterlo su GitHub)"
