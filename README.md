# Ukeep

App Flutter (Android) per due persone: attività, liste, calendario, progetti e desideri condivisi.
Login Google, dati su Firestore (sincronizzati e disponibili offline).

L'APK viene compilato da GitHub Actions (.github/workflows/build.yml) e pubblicato in Releases.
La cartella `android/` viene generata in automatico a ogni build.

Servono nel repo: `google-services.json` (dalla console Firebase) e i secret
`KEYSTORE_B64` e `KEYSTORE_PASSWORD` (vedi scripts/make_keystore.sh).
Le regole Firestore sono in `firestore.rules`.

Il keystore (.jks) non va MAI su GitHub: fai un backup e conservalo.

## Webapp

La stessa app gira anche nel browser: https://dvdsalviato.github.io/ukeep/
(stessi dati dell'app Android). Viene compilata e pubblicata da
`.github/workflows/web.yml` a ogni push su `main`; la cartella `web/` è generata
da `scripts/bootstrap_web.sh`.

Configurazione (una volta sola):
1. Console Firebase → Impostazioni progetto → Aggiungi app → Web (`</>`).
   Copia il blocco `firebaseConfig` e incollalo così com'è nel secret GitHub
   `FIREBASE_WEB_CONFIG`.
2. Firebase → Authentication → Impostazioni → Domini autorizzati:
   aggiungi `dvdsalviato.github.io`.
3. GitHub → Settings → Pages → Source: **GitHub Actions**.

Sul web non ci sono notifiche, push al partner, widget e sblocco con impronta.
La chiave delle push (`fcm_sa.json`) non viene mai inclusa nel sito.
