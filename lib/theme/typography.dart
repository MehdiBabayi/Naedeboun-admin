import 'package:flutter/material.dart';

/// Centralized text styles. Uses the global font already configured.
class AppTypography {
  AppTypography._();

  // Base sizes
  static const double bodySize = 14;
  static const double titleSize = 20;
  static const double headlineSize = 24;

  // Light theme text styles
  static const TextTheme lightTextTheme = TextTheme(
    bodyLarge: TextStyle(fontSize: 16),
    bodyMedium: TextStyle(fontSize: bodySize),
    bodySmall: TextStyle(fontSize: 12),
    titleLarge: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(fontSize: headlineSize, fontWeight: FontWeight.w800),
  );

  // Dark theme text styles
  static const TextTheme darkTextTheme = TextTheme(
    bodyLarge: TextStyle(fontSize: 16, color: Colors.white),
    bodyMedium: TextStyle(fontSize: bodySize, color: Colors.white),
    bodySmall: TextStyle(fontSize: 12, color: Colors.white70),
    titleLarge: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w700, color: Colors.white),
    titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
    titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
    headlineSmall: TextStyle(fontSize: headlineSize, fontWeight: FontWeight.w800, color: Colors.white),
  );
}


