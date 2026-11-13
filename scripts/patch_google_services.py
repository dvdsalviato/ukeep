import pathlib
import re
import sys

VERSION = "4.4.2"

# settings.gradle.kts: dichiara il plugin
sp = pathlib.Path("android/settings.gradle.kts")
s = sp.read_text()
if "com.google.gms.google-services" not in s:
    pat = r'(\n[ \t]*)id\("com\.android\.application"\) version "[^"]+" apply false'
    m = re.search(pat, s)
    if not m:
        sys.exit("settings.gradle.kts: plugin com.android.application non trovato")
    ins = f'{m.group(1)}id("com.google.gms.google-services") version "{VERSION}" apply false'
    s = s[:m.end()] + ins + s[m.end():]
    sp.write_text(s)

# app/build.gradle.kts: applica il plugin
ap = pathlib.Path("android/app/build.gradle.kts")
a = ap.read_text()
if "com.google.gms.google-services" not in a:
    pat = r'(\n[ \t]*)id\("com\.android\.application"\)'
    m = re.search(pat, a)
    if not m:
        sys.exit("app/build.gradle.kts: plugin com.android.application non trovato")
    ins = f'{m.group(1)}id("com.google.gms.google-services")'
    a = a[:m.end()] + ins + a[m.end():]
    ap.write_text(a)
print("google-services configurato")
