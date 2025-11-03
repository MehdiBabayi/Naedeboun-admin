import 'package:flutter/material.dart';

/// Centralized color schemes for light and dark themes.
/// All colors are defined here for better organization and maintainability.
class AppColorSchemes {
  AppColorSchemes._();

  // رنگ‌های اصلی
  static const Color primaryBlue = Color(0xFF4169E1); // آبی آسمانی پررنگ
  static const Color secondaryBlue = Color(0xFF1976D2); // آبی ثانویه
  static const Color lightBlue = Color(0xFFE3F2FD); // آبی روشن
  static const Color darkBlue = Color(0xFF0D47A1); // آبی تیره

  // قرمزها
  static const Color primaryRed = Color(0xFFE53E3E); // قرمز اصلی
  static const Color secondaryRed = Color(0xFFC53030); // قرمز ثانویه
  static const Color lightRed = Color(0xFFFED7D7); // قرمز روشن
  static const Color darkRed = Color(0xFF9B2C2C); // قرمز تیره

  // خاکستری‌ها
  static const Color primaryGrey = Color(0xFF6B7280); // خاکستری اصلی
  static const Color secondaryGrey = Color(0xFF9CA3AF); // خاکستری ثانویه
  static const Color lightGrey = Color(0xFFF3F4F6); // خاکستری روشن
  static const Color darkGrey = Color(0xFF374151); // خاکستری تیره

  // سفید و مشکی
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // رنگ‌های پس‌زمینه
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color backgroundGrey = Color(0xFFF5F5F5);

  // رنگ‌های متن
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);

  // رنگ‌های Border
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderMedium = Color(0xFFD1D5DB);
  static const Color borderDark = Color(0xFF9CA3AF);

  // رنگ‌های Success و Warning
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // رنگ‌های سرمه‌ای
  static const Color navyBlue = Color(0xFF1B1E34); // سرمه‌ای تیره
  static const Color darkNavyBlue = Color(0xFF121420); // سرمه‌ای خیلی تیره
  static const Color deepSlateBlue = Color(0xFF2F2F42); // رنگ جدید سرمه‌ای عمیق

  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,
    primary: primaryBlue,
    onPrimary: white,
    secondary: secondaryBlue,
    onSecondary: white,
    error: error,
    onError: white,
    surface: backgroundWhite,
    onSurface: textPrimary,
  );

  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,
    primary: primaryBlue,
    onPrimary: white,
    secondary: secondaryBlue,
    onSecondary: white,
    error: error,
    onError: white,
    surface: navyBlue, // سرمه‌ای تیره برای پس‌زمینه
    onSurface: white,
    surfaceContainerHighest: darkGrey, // سطح متغیر تاریک
    onSurfaceVariant: textLight, // متن روی سطح متغیر
  );
}


