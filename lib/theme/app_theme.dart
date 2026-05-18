import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class AppTheme {
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppConstants.kPrimary,
        onPrimary: Colors.white,
        secondary: AppConstants.kPrimary,
        onSecondary: Colors.white,
        error: Color(0xFFEF4444),
        onError: Colors.white,
        surface: AppConstants.kBackground,
        onSurface: AppConstants.kTextPrimary,
        outline: AppConstants.kBorder,
        surfaceContainerHighest: AppConstants.kSurface,
      ),
      scaffoldBackgroundColor: AppConstants.kBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppConstants.kSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppConstants.kTextPrimary,
        titleTextStyle: TextStyle(
          fontSize: AppConstants.appBarFontSize,
          fontWeight: FontWeight.w600,
          color: AppConstants.kTextPrimary,
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppConstants.kSurface,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppConstants.kBorder,
        space: 1,
        thickness: 1,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppConstants.kTextPrimary,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppConstants.kTextPrimary,
          letterSpacing: -0.3,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: AppConstants.kTextPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: AppConstants.kTextPrimary),
        bodySmall: TextStyle(fontSize: 12, color: AppConstants.kTextSecondary),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AppConstants.kPrimary,
        onPrimary: Colors.white,
        secondary: AppConstants.kPrimary,
        onSecondary: Colors.white,
        error: Color(0xFFEF4444),
        onError: Colors.white,
        surface: AppConstants.kDarkBackground,
        onSurface: AppConstants.kDarkTextPrimary,
        outline: AppConstants.kDarkBorder,
        surfaceContainerHighest: AppConstants.kDarkSurface,
      ),
      scaffoldBackgroundColor: AppConstants.kDarkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppConstants.kDarkBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppConstants.kDarkTextPrimary,
        titleTextStyle: TextStyle(
          fontSize: AppConstants.appBarFontSize,
          fontWeight: FontWeight.w600,
          color: AppConstants.kDarkTextPrimary,
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppConstants.kDarkSurface,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppConstants.kDarkBorder,
        space: 1,
        thickness: 1,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppConstants.kDarkTextPrimary,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppConstants.kDarkTextPrimary,
          letterSpacing: -0.3,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: AppConstants.kDarkTextPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: AppConstants.kDarkTextPrimary),
        bodySmall: TextStyle(fontSize: 12, color: AppConstants.kDarkTextSecondary),
      ),
    );
  }
}
