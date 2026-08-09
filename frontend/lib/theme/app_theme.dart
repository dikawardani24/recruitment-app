import 'package:flutter/material.dart';

/// Seed color for the app's Material 3 color scheme.
const Color kSeedColor = Color(0xFF3F51B5);

ThemeData _buildTheme(Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: kSeedColor,
      brightness: brightness,
    ),
    useMaterial3: true,
  );
}

/// Light theme used for [ThemeMode.light] (and the system default).
ThemeData buildLightTheme() => _buildTheme(Brightness.light);

/// Dark theme used for [ThemeMode.dark] (and a dark system setting).
ThemeData buildDarkTheme() => _buildTheme(Brightness.dark);
