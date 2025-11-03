import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xFF3629B7), // آبی بنفش یکسان با نویگیشن
    scaffoldBackgroundColor: const Color(0xFFFFFFFF), // White
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF3629B7), // آبی بنفش یکسان با نویگیشن
      onPrimary: Color(0xFFFFFFFF), // White
      secondary: Color(0xFF42A5F5), // Light Blue
      onSecondary: Color(0xFFFFFFFF), // White
      surface: Color(0xFFFFFFFF), // White
      onSurface: Color(0xFF212121), // Black
      error: Color(0xFFB00020),
      onError: Color(0xFFFFFFFF),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(
        color: Color(0xFF212121),
        fontFamily: 'IRANSansXFaNum',
      ),
      bodyMedium: TextStyle(
        color: Color(0xFF757575),
        fontFamily: 'IRANSansXFaNum',
      ),
      titleLarge: TextStyle(
        fontFamily: 'IRANSansXFaNum',
        fontWeight: FontWeight.bold,
      ),
      titleMedium: TextStyle(fontFamily: 'IRANSansXFaNum'),
      titleSmall: TextStyle(fontFamily: 'IRANSansXFaNum'),
      labelLarge: TextStyle(fontFamily: 'IRANSansXFaNum'),
      labelMedium: TextStyle(fontFamily: 'IRANSansXFaNum'),
      labelSmall: TextStyle(fontFamily: 'IRANSansXFaNum'),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFFFFFF),
      foregroundColor: Color(0xFF212121),
      elevation: 0,
    ),
    buttonTheme: const ButtonThemeData(
      buttonColor: Color(0xFF3629B7),
      textTheme: ButtonTextTheme.primary,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF3629B7), // آبی بنفش یکسان با نویگیشن
    scaffoldBackgroundColor: const Color(0xFF121212), // Almost Black
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF3629B7), // آبی بنفش یکسان با نویگیشن
      onPrimary: Color(0xFF000000), // Black
      secondary: Color(0xFF0D47A1), // Navy Blue
      onSecondary: Color(0xFFFFFFFF), // White
      surface: Color(0xFF2C2C2C), // Lighter Grey
      onSurface: Color(0xFFFFFFFF), // White
      error: Color(0xFFCF6679),
      onError: Color(0xFF000000),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(
        color: Color(0xFFFFFFFF),
        fontFamily: 'IRANSansXFaNum',
      ),
      bodyMedium: TextStyle(
        color: Color(0xFFBDBDBD),
        fontFamily: 'IRANSansXFaNum',
      ),
      titleLarge: TextStyle(
        fontFamily: 'IRANSansXFaNum',
        fontWeight: FontWeight.bold,
      ),
      titleMedium: TextStyle(fontFamily: 'IRANSansXFaNum'),
      titleSmall: TextStyle(fontFamily: 'IRANSansXFaNum'),
      labelLarge: TextStyle(fontFamily: 'IRANSansXFaNum'),
      labelMedium: TextStyle(fontFamily: 'IRANSansXFaNum'),
      labelSmall: TextStyle(fontFamily: 'IRANSansXFaNum'),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1F1F1F),
      foregroundColor: Color(0xFFFFFFFF),
      elevation: 0,
    ),
    buttonTheme: const ButtonThemeData(
      buttonColor: Color(0xFF3629B7),
      textTheme: ButtonTextTheme.primary,
    ),
  );
}
