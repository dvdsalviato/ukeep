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

# --- Widget per la schermata Home e notifiche push (FCM)
m = mp.read_text()
if "UkeepWidget" not in m:
    extra = (
        '        <receiver android:name=".UkeepWidget" android:exported="true">\n'
        "            <intent-filter>\n"
        '                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />\n'
        "            </intent-filter>\n"
        '            <meta-data android:name="android.appwidget.provider" android:resource="@xml/ukeep_widget_info" />\n'
        "        </receiver>\n"
        '        <meta-data android:name="com.google.firebase.messaging.default_notification_icon" android:resource="@drawable/ic_stat" />\n'
        '        <meta-data android:name="com.google.firebase.messaging.default_notification_color" android:resource="@color/ukeep_accent" />\n'
        '        <meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" android:value="ukeep_partner" />\n'
        "    "
    )
    m = m.replace("</application>", extra + "</application>", 1)
    mp.write_text(m)
    print("AndroidManifest: widget e push configurati")

# --- Apertura link (download aggiornamenti) su Android 11+
m = mp.read_text()
if "android.intent.action.VIEW" not in m:
    q = (
        "    <queries>\n"
        "        <intent>\n"
        '            <action android:name="android.intent.action.VIEW" />\n'
        '            <data android:scheme="https" />\n'
        "        </intent>\n"
        "    </queries>\n"
    )
    m = m.replace("</manifest>", q + "</manifest>", 1)
    mp.write_text(m)
    print("AndroidManifest: apertura link configurata")

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
