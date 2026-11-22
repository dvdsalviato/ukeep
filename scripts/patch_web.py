"""Nome, colori e icone della webapp (cartella web/ generata da flutter create)."""
import json
import pathlib

from PIL import Image

web = pathlib.Path("web")
src = Image.open("assets/icon.png").convert("RGBA")
BG = "#FFE9DC"

(web / "icons").mkdir(exist_ok=True)
for name, size in [("Icon-192", 192), ("Icon-512", 512)]:
    src.resize((size, size), Image.LANCZOS).save(web / "icons" / f"{name}.png")
    # maskable: logo un po' rimpicciolito su sfondo pieno
    canvas = Image.new("RGBA", (size, size), BG)
    inner = int(size * 0.8)
    off = (size - inner) // 2
    canvas.paste(src.resize((inner, inner), Image.LANCZOS), (off, off),
                 src.resize((inner, inner), Image.LANCZOS))
    canvas.save(web / "icons" / f"{name.replace('Icon', 'Icon-maskable')}.png")
src.resize((64, 64), Image.LANCZOS).save(web / "favicon.png")

m = web / "manifest.json"
j = json.loads(m.read_text())
j.update({
    "name": "Ukeep",
    "short_name": "Ukeep",
    "description": "Attività, liste, calendario e progetti di coppia.",
    "background_color": BG,
    "theme_color": BG,
    "orientation": "portrait-primary",
})
m.write_text(json.dumps(j, indent=2, ensure_ascii=False))

i = web / "index.html"
s = i.read_text()
s = s.replace("<title>ukeep</title>", "<title>Ukeep</title>")
s = s.replace('content="ukeep"', 'content="Ukeep"')
s = s.replace('content="A new Flutter project."',
              'content="Ukeep: attività, liste e calendario di coppia."')
if 'name="theme-color"' not in s:
    s = s.replace("</head>", f'  <meta name="theme-color" content="{BG}">\n</head>', 1)
s = s.replace('<html>', '<html lang="it">', 1)
i.write_text(s)
print("web/ configurata (nome, icone, colori)")
