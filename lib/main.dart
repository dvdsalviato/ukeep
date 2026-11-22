import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/app_lock.dart';
import 'core/push.dart';
import 'core/theme.dart';
import 'core/web_config.dart';
import 'core/widget_sync.dart';
import 'core/update.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT');
  if (kIsWeb) {
    // webapp: stessi dati dell'app, niente widget, push o impronta
    if (!webConfigured) {
      runApp(const _MissingWebConfig());
      return;
    }
    await Firebase.initializeApp(options: webFirebaseOptions);
  } else {
    await Firebase.initializeApp();
    await GoogleSignIn.instance.initialize();
  }
  await ThemeCtl.load();
  await AppVersion.load();
  await LockCtl.load();
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    try {
      HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
    } catch (_) {}
  }
  runApp(const ProviderScope(child: UkeepApp()));
}

class _MissingWebConfig extends StatelessWidget {
  const _MissingWebConfig();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'Ukeep web non è ancora configurata.\n\n'
                'Manca il secret FIREBASE_WEB_CONFIG su GitHub '
                '(vedi README).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17),
              ),
            ),
          ),
        ),
      );
}
