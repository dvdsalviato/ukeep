import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'core/ui.dart';
import 'data/providers.dart';
import 'features/auth/login_page.dart';
import 'features/couple/couple_page.dart';
import 'features/shell/home_shell.dart';

class UkeepApp extends StatelessWidget {
  const UkeepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ukeep',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('it', 'IT'),
      supportedLocales: const [Locale('it', 'IT')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) =>
          GradientBg(child: child ?? const SizedBox.shrink()),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      loading: () => const _Splash(),
      error: (e, _) => Scaffold(body: Center(child: Text('Errore: $e'))),
      data: (user) {
        if (user == null) return const LoginPage();
        final couple = ref.watch(coupleIdProvider);
        return couple.when(
          loading: () => const _Splash(),
          error: (e, _) => Scaffold(body: Center(child: Text('Errore: $e'))),
          data: (id) => id == null ? const CouplePage() : HomeShell(coupleId: id),
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Image.asset('assets/logo.png', width: 120, height: 120),
        ),
      );
}
