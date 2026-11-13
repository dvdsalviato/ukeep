import pathlib
import sys

p = pathlib.Path("pubspec.yaml")
if not p.exists():
    sys.exit("pubspec.yaml non trovato (esegui prima bootstrap.sh)")

s = p.read_text()

if "- assets/" not in s:
    marker = "uses-material-design: true"
    if marker not in s:
        sys.exit("pubspec.yaml: 'uses-material-design: true' non trovato")
    s = s.replace(marker, marker + "\n  assets:\n    - assets/", 1)

if "flutter_launcher_icons:" not in s:
    s = s.rstrip("\n") + (
        "\n\nflutter_launcher_icons:\n"
        "  android: true\n"
        "  ios: false\n"
        '  image_path: "assets/icon.png"\n'
    )

p.write_text(s)
print("pubspec.yaml configurato (assets + icona)")
