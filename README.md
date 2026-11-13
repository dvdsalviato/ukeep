# Ukeep

App Flutter (Android) per due persone: attività, liste, calendario, progetti e desideri condivisi.
Login Google, dati su Firestore (sincronizzati e disponibili offline).

L'APK viene compilato da GitHub Actions (.github/workflows/build.yml) e pubblicato in Releases.
La cartella `android/` viene generata in automatico a ogni build.

Servono nel repo: `google-services.json` (dalla console Firebase) e i secret
`KEYSTORE_B64` e `KEYSTORE_PASSWORD` (vedi scripts/make_keystore.sh).
Le regole Firestore sono in `firestore.rules`.

Il keystore (.jks) non va MAI su GitHub: fai un backup e conservalo.
