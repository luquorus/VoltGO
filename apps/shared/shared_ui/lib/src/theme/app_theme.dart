import 'package:flutter/material.dart';

/// Green Energy Theme - Material 3
/// 
/// Tông xanh lá hiện đại với:
/// - Primary: Green energy
/// - Secondary: Mint/Teal nhẹ
/// - Surface: Sáng, thoáng
/// - Border radius: 14-18
/// - Shadow nhẹ
class AppTheme {
  // Color palette
  static const Color primaryGreen = Color(0xFF2E7D32); // Green 800
  static const Color primaryGreenLight = Color(0xFF4CAF50); // Green 500
  static const Color primaryGreenDark = Color(0xFF1B5E20); // Green 900
  
  static const Color secondaryMint = Color(0xFF80CBC4); // Teal 200
  static const Color secondaryTeal = Color(0xFF26A69A); // Teal 500
  
  static const Color surfaceLight = Color(0xFFF5F5F5);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  
  static const Color outlineLight = Color(0xFFE0E0E0);
  static const Color outlineMedium = Color(0xFFBDBDBD);

  /// Light theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: primaryGreen,
      primaryContainer: primaryGreenLight,
      secondary: secondaryTeal,
      secondaryContainer: secondaryMint,
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
        borderSide: const BorderSide(color: primaryGreen, width: 2),
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
  );

  /// Dark theme (nice-to-have)
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: primaryGreenLight,
      primaryContainer: primaryGreen,
      secondary: secondaryMint,
      secondaryContainer: secondaryTeal,
      surface: const Color(0xFF1C1B1F),
      surfaceContainerHighest: const Color(0xFF2C2B2F),
      outline: const Color(0xFF3C3B3F),
      outlineVariant: const Color(0xFF4C4B4F),
      error: const Color(0xFFFFB4AB),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
      onError: const Color(0xFF690005),
    ),
    textTheme: _textThemeDark,
    cardTheme: CardThemeData(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.3),
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
      fillColor: const Color(0xFF2C2B2F),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF3C3B3F)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF3C3B3F)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryGreenLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFFB4AB)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      titleSpacing: 16,
    ),
  );

  /// Text theme - hierarchy rõ
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

  static const TextTheme _textThemeDark = TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      letterSpacing: 0,
      color: Colors.white,
    ),
    displayMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      letterSpacing: 0,
      color: Colors.white,
    ),
    displaySmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: Colors.white,
    ),
    headlineLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: Colors.white,
    ),
    headlineMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: Colors.white,
    ),
    headlineSmall: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: Colors.white,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
      color: Colors.white,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.15,
      color: Colors.white,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: Colors.white,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      letterSpacing: 0.5,
      color: Colors.white,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      letterSpacing: 0.25,
      color: Colors.white,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      letterSpacing: 0.4,
      color: Color(0xFFCAC4D0),
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: Colors.white,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      color: Color(0xFFCAC4D0),
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      color: Color(0xFFCAC4D0),
    ),
  );

  /// Spacing constants
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  /// Border radius
  static const double radiusS = 8.0;
  static const double radiusM = 14.0;
  static const double radiusL = 18.0;
  static const double radiusXL = 24.0;
}

