import 'package:flutter/material.dart';

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFC2185B),
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFFFF7F3),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
  );
}
