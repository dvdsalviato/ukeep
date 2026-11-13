import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tema chiaro / scuro. Si cambia con il sole/luna in Home.
class ThemeCtl {
  ThemeCtl._();
  static final ValueNotifier<bool> dark = ValueNotifier<bool>(false);

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getBool('dark');
      dark.value = v ??
          (WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);
    } catch (_) {}
  }

  static Future<void> toggle() async {
    dark.value = !dark.value;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('dark', dark.value);
    } catch (_) {}
  }
}

bool get isDark => ThemeCtl.dark.value;

class UColors {
  UColors._();
  static Color get ink =>
      isDark ? const Color(0xFFF1EBF5) : const Color(0xFF2A2430);
  static Color get muted =>
      isDark ? const Color(0xFFA89EB2) : const Color(0xFF8C8294);
  static Color get accent =>
      isDark ? const Color(0xFFE3A26B) : const Color(0xFFB9743C);
  static Color get rose =>
      isDark ? const Color(0xFFC98273) : const Color(0xFFE8A090);
  static Color get lilac =>
      isDark ? const Color(0xFFBBA0E3) : const Color(0xFF9B7BC8);

  /// Colore dei pulsanti "pillola" (nero in chiaro, chiaro in scuro).
  static Color get dark =>
      isDark ? const Color(0xFFF1EBF5) : const Color(0xFF1F1B24);

  /// Testo/icone sopra [dark].
  static Color get onDark =>
      isDark ? const Color(0xFF1F1B24) : Colors.white;
  static Color get danger =>
      isDark ? const Color(0xFFEA7690) : const Color(0xFFB03A55);
  static Color get bgTop =>
      isDark ? const Color(0xFF2C2230) : const Color(0xFFFFE9DC);
  static Color get bgMid =>
      isDark ? const Color(0xFF241F2B) : const Color(0xFFFAEFF3);
  static Color get bgBottom =>
      isDark ? const Color(0xFF1E1A2C) : const Color(0xFFEDE2FA);

  /// Sfondo delle card.
  static Color get card => isDark
      ? const Color(0xFF302A38).withAlpha(235)
      : Colors.white.withAlpha(215);

  /// Sfondo pieno (fogli, finestre).
  static Color get surface =>
      isDark ? const Color(0xFF26212D) : Colors.white;
}

TextStyle serif(double size,
    {FontWeight weight = FontWeight.w600, FontStyle? style, Color? color}) {
  return TextStyle(
    fontFamily: 'serif',
    fontSize: size,
    fontWeight: weight,
    fontStyle: style,
    color: color ?? UColors.ink,
    height: 1.1,
  );
}

SystemUiOverlayStyle get systemBars => isDark
    ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
    : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent);

ThemeData buildTheme() {
  final b = isDark ? Brightness.dark : Brightness.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: UColors.rose,
    brightness: b,
  ).copyWith(
    primary: UColors.dark,
    onPrimary: UColors.onDark,
    secondary: UColors.accent,
    surface: UColors.surface,
    onSurface: UColors.ink,
  );
  final base = (isDark ? ThemeData.dark() : ThemeData.light()).textTheme.apply(
        bodyColor: UColors.ink,
        displayColor: UColors.ink,
      );
  final text = base.copyWith(
    displayMedium: serif(46),
    headlineMedium: serif(34),
    headlineSmall: serif(26),
    titleLarge: serif(22),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: Colors.transparent,
    iconTheme: IconThemeData(color: UColors.ink),
    dialogTheme: DialogThemeData(backgroundColor: UColors.surface),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: UColors.dark,
      contentTextStyle: TextStyle(color: UColors.onDark, fontSize: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: UColors.ink,
      titleTextStyle: serif(22),
      systemOverlayStyle: systemBars,
    ),
  );
}
