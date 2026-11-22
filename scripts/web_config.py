"""Legge il secret FIREBASE_WEB_CONFIG e scrive web_defines.json per
`flutter build web --dart-define-from-file`.

Nel secret si può incollare così com'è il blocco che mostra la console
Firebase (const firebaseConfig = { apiKey: "...", ... };) oppure un JSON.
"""
import json
import os
import re

raw = os.environ.get("FIREBASE_WEB_CONFIG", "")
pairs = dict(re.findall(r'["\']?(\w+)["\']?\s*:\s*["\']([^"\']*)["\']', raw))

keys = {
    "apiKey": "FB_API_KEY",
    "appId": "FB_APP_ID",
    "messagingSenderId": "FB_SENDER_ID",
    "projectId": "FB_PROJECT_ID",
    "authDomain": "FB_AUTH_DOMAIN",
    "storageBucket": "FB_STORAGE_BUCKET",
}
out = {d: pairs[k] for k, d in keys.items() if pairs.get(k)}
with open("web_defines.json", "w") as f:
    json.dump(out, f)

if "FB_API_KEY" in out and "FB_APP_ID" in out:
    print("Configurazione web trovata:", ", ".join(sorted(out)))
else:
    print("::warning::Manca il secret FIREBASE_WEB_CONFIG: la webapp mostrerà "
          "'non ancora configurata'")
