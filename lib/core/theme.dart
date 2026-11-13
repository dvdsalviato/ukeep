import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UColors {
  UColors._();
  static const ink = Color(0xFF2A2430);
  static const muted = Color(0xFF8C8294);
  static const accent = Color(0xFFB9743C);
  static const rose = Color(0xFFE8A090);
  static const lilac = Color(0xFF9B7BC8);
  static const dark = Color(0xFF1F1B24);
  static const danger = Color(0xFFB03A55);
  static const bgTop = Color(0xFFFFE9DC);
  static const bgMid = Color(0xFFFAEFF3);
  static const bgBottom = Color(0xFFEDE2FA);
}

TextStyle serif(double size,
    {FontWeight weight = FontWeight.w600, FontStyle? style, Color? color}) {
  return GoogleFonts.newsreader(
    fontSize: size,
    fontWeight: weight,
    fontStyle: style,
    color: color ?? UColors.ink,
    height: 1.1,
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: UColors.rose,
    brightness: Brightness.light,
  ).copyWith(
    primary: UColors.dark,
    onPrimary: Colors.white,
    secondary: UColors.accent,
    surface: Colors.white,
  );
  final base = GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
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
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: Colors.transparent,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: UColors.dark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: UColors.ink,
      titleTextStyle: serif(22),
    ),
  );
}
