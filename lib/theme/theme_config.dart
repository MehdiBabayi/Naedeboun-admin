import 'package:flutter/material.dart';
import 'color_schemes.dart';
import 'typography.dart';

/// A configurable theme container to manage light/dark themes in one place.
/// You can change colors, text styles, and component themes here globally.
class AppThemeConfig {
  AppThemeConfig({this.useMaterial3 = true});

  final bool useMaterial3;

  ThemeData buildLightTheme() {
    return ThemeData(
      useMaterial3: useMaterial3,
      colorScheme: AppColorSchemes.light,
      fontFamily: 'IRANSansXFaNum',
      scaffoldBackgroundColor: AppColorSchemes.light.surface,
      textTheme: AppTypography.lightTextTheme.apply(
        fontFamily: 'IRANSansXFaNum',
        bodyColor: AppColorSchemes.light.onSurface,
        displayColor: AppColorSchemes.light.onSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColorSchemes.white,
        elevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorSchemes.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorSchemes.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorSchemes.primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorSchemes.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorSchemes.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelStyle: const TextStyle(fontSize: 14, color: AppColorSchemes.textSecondary),
        hintStyle: const TextStyle(fontSize: 14, color: AppColorSchemes.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: AppColorSchemes.dark.brightness == Brightness.dark 
            ? AppColorSchemes.deepSlateBlue  // تم تاریک
            : Colors.grey[300],  // تم روشن
          foregroundColor: AppColorSchemes.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  ThemeData buildDarkTheme() {
    return ThemeData(
      useMaterial3: useMaterial3,
      colorScheme: AppColorSchemes.dark,
      fontFamily: 'IRANSansXFaNum',
      scaffoldBackgroundColor: AppColorSchemes.dark.surface,
      textTheme: AppTypography.darkTextTheme.apply(
        fontFamily: 'IRANSansXFaNum',
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121212),
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorSchemes.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorSchemes.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorSchemes.primaryBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelStyle: const TextStyle(fontSize: 14, color: Colors.white70),
        hintStyle: const TextStyle(fontSize: 14, color: Colors.white60),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: AppColorSchemes.primaryBlue,
          foregroundColor: AppColorSchemes.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}


