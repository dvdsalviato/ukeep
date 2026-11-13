import pathlib
import sys

# --- AndroidManifest: permessi e ricevitori per le notifiche programmate
mp = pathlib.Path("android/app/src/main/AndroidManifest.xml")
m = mp.read_text()
if "ScheduledNotificationReceiver" not in m:
    if "<application" not in m or "</application>" not in m:
        sys.exit("AndroidManifest.xml: tag application non trovato")
    perms = (
        '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n'
        '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>\n'
        '    <uses-permission android:name="android.permission.VIBRATE"/>\n'
        '    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" android:maxSdkVersion="32"/>\n'
        '    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>\n'
        "    "
    )
    receivers = (
        '        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />\n'
        '        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">\n'
        "            <intent-filter>\n"
        '                <action android:name="android.intent.action.BOOT_COMPLETED"/>\n'
        '                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\n'
        '                <action android:name="android.intent.action.QUICKBOOT_POWERON" />\n'
        '                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>\n'
        "            </intent-filter>\n"
        "        </receiver>\n"
        "    "
    )
    m = m.replace("<application", perms + "<application", 1)
    m = m.replace("</application>", receivers + "</application>", 1)
    mp.write_text(m)
    print("AndroidManifest: notifiche configurate")

# --- Gradle: core library desugaring (richiesto da flutter_local_notifications)
gp = pathlib.Path("android/app/build.gradle.kts")
g = gp.read_text()
if "isCoreLibraryDesugaringEnabled" not in g:
    if "compileOptions {" in g:
        g = g.replace(
            "compileOptions {",
            "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
            1,
        )
    elif "\nandroid {" in g:
        g = g.replace(
            "\nandroid {",
            "\nandroid {\n    compileOptions {\n        isCoreLibraryDesugaringEnabled = true\n    }",
            1,
        )
    else:
        sys.exit("build.gradle.kts: blocco android non trovato")
if "coreLibraryDesugaring(" not in g:
    g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
gp.write_text(g)
print("build.gradle.kts: desugaring configurato")
