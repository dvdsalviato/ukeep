import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/theme.dart';
import 'core/update.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT');
  await Firebase.initializeApp();
  await GoogleSignIn.instance.initialize();
  await ThemeCtl.load();
  await AppVersion.load();
  runApp(const ProviderScope(child: UkeepApp()));
}
