import 'package:flutter/material.dart';

/// Admin Web Theme - Green-Blue/Teal
/// 
/// Tông màu xanh lá ngả lam (teal/cyan)
class AdminTheme {
  // Green-blue/Teal color palette
  static const Color primaryTeal = Color(0xFF00897B); // Teal 600 - xanh lá ngả lam
  static const Color primaryTealLight = Color(0xFF26A69A); // Teal 500
  static const Color primaryTealDark = Color(0xFF00695C); // Teal 700
  
  static const Color secondaryCyan = Color(0xFF00ACC1); // Cyan 600
  static const Color secondaryCyanLight = Color(0xFF4DD0E1); // Cyan 300
  
  static const Color surfaceLight = Color(0xFFF5F5F5);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  
  static const Color outlineLight = Color(0xFFE0E0E0);
  static const Color outlineMedium = Color(0xFFBDBDBD);
  
  // Sidebar colors
  static const Color sidebarBackground = Color(0xFFFAFAFA);
  static const Color sidebarActiveBackground = Color(0xFFE0F2F1);

  /// Light theme with teal/cyan
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: primaryTeal, // Teal - xanh lá ngả lam
      primaryContainer: primaryTealLight,
      secondary: secondaryCyan,
      secondaryContainer: secondaryCyanLight,
      surface: surfaceWhite,
      surfaceContainerHighest: surfaceLight,
      outline: outlineLight,
      outlineVariant: outlineMedium,
      error: const Color(0xFFBA1A1A),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: const Color(0xFF1C1B1F),
      onError: Colors.white,
    ),
    textTheme: _textTheme,
    cardTheme: CardThemeData(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.all(8),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: outlineLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: outlineLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryTeal, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFBA1A1A)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      titleSpacing: 16,
    ),
    iconTheme: const IconThemeData(
      color: Color(0xFF1C1B1F),
    ),
  );

  /// Text theme
  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      letterSpacing: 0,
      color: Color(0xFF1C1B1F),
    ),
    displayMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      letterSpacing: 0,
      color: Color(0xFF1C1B1F),
    ),
    displaySmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: Color(0xFF1C1B1F),
    ),
    headlineLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: Color(0xFF1C1B1F),
    ),
    headlineMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: Color(0xFF1C1B1F),
    ),
    headlineSmall: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: Color(0xFF1C1B1F),
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
      color: Color(0xFF1C1B1F),
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.15,
      color: Color(0xFF1C1B1F),
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: Color(0xFF1C1B1F),
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      letterSpacing: 0.5,
      color: Color(0xFF1C1B1F),
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      letterSpacing: 0.25,
      color: Color(0xFF1C1B1F),
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      letterSpacing: 0.4,
      color: Color(0xFF49454F),
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: Color(0xFF1C1B1F),
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      color: Color(0xFF49454F),
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      color: Color(0xFF49454F),
    ),
  );
}

