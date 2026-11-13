import pathlib
import sys

p = pathlib.Path("android/app/build.gradle.kts")
if not p.exists():
    sys.exit("android/app/build.gradle.kts non trovato (esegui prima bootstrap.sh)")

s = p.read_text()
if "keystoreProperties" in s:
    print("build.gradle.kts già configurato")
    sys.exit(0)

loader = '''val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

'''

new_blocks = '''    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        // Stessa firma in debug e release: gli aggiornamenti si installano
        // sempre sopra l'app esistente, senza disinstallare.
        getByName("debug") {
            signingConfig = signingConfigs.getByName("release")
        }
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
'''

# individua il blocco buildTypes { ... } con conteggio parentesi
start = s.index("buildTypes {")
line_start = s.rfind("\n", 0, start) + 1
i = s.index("{", start)
depth = 0
while True:
    if s[i] == "{":
        depth += 1
    elif s[i] == "}":
        depth -= 1
        if depth == 0:
            break
    i += 1
end = i + 1
if s[end:end + 1] == "\n":
    end += 1
s = s[:line_start] + new_blocks + s[end:]

idx = s.index("\nandroid {") + 1
s = s[:idx] + loader + s[idx:]
s = "import java.io.FileInputStream\nimport java.util.Properties\n\n" + s
p.write_text(s)
print("build.gradle.kts aggiornato")

# disattiva il lint di release (va in crash in questo ambiente)
s = p.read_text()
if "checkReleaseBuilds" not in s:
    s = s.replace("android {", "android {\n    lint {\n        checkReleaseBuilds = false\n        abortOnError = false\n    }\n", 1)
    p.write_text(s)
