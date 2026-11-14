import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/app_lock.dart';
import 'core/push.dart';
import 'core/theme.dart';
import 'core/widget_sync.dart';
import 'core/update.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT');
  await Firebase.initializeApp();
  await GoogleSignIn.instance.initialize();
  await ThemeCtl.load();
  await AppVersion.load();
  await LockCtl.load();
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  try {
    HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
  } catch (_) {}
  runApp(const ProviderScope(child: UkeepApp()));
}
