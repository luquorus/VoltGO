import 'package:flutter/material.dart';

class SimulatorTheme {
  SimulatorTheme._();

  // Primary colors
  static const Color primaryTeal = Color(0xFF009688);
  static const Color primaryTealLight = Color(0xFF4DB6AC);
  static const Color primaryTealDark = Color(0xFF00796B);
  
  // Accent color
  static const Color accentAmber = Color(0xFFFFC107);
  
  // Background colors (dark theme)
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardDark = Color(0xFF2D2D2D);
  
  // Status colors
  static const Color statusOnline = Color(0xFF4CAF50);
  static const Color statusCharging = Color(0xFFFFC107);
  static const Color statusReserved = Color(0xFF2196F3);
  static const Color statusOccupied = Color(0xFF9C27B0);
  static const Color statusSwappedOut = Color(0xFF757575);
  static const Color statusAvailable = Color(0xFF4CAF50);
  static const Color statusMaintenance = Color(0xFFF44336);
  
  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textDisabled = Color(0xFF757575);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryTeal,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryTeal,
        secondary: accentAmber,
        surface: surfaceDark,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTeal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryTeal,
          side: const BorderSide(color: primaryTeal),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryTeal,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryTeal, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      iconTheme: const IconThemeData(
        color: textSecondary,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.1),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardDark,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  static Color getSlotStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'AVAILABLE':
        return statusAvailable;
      case 'CHARGING':
        return statusCharging;
      case 'RESERVED':
        return statusReserved;
      case 'OCCUPIED':
        return statusOccupied;
      case 'SWAPPED_OUT':
        return statusSwappedOut;
      default:
        return statusSwappedOut;
    }
  }

  static Color getPileStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return statusOnline;
      case 'MAINTENANCE':
        return statusMaintenance;
      case 'STOPPED':
        return statusMaintenance;
      case 'ERROR':
        return Colors.orange;
      default:
        return statusSwappedOut;
    }
  }

  static IconData getSlotBatteryIcon(String status) {
    switch (status.toUpperCase()) {
      case 'AVAILABLE':
        return Icons.battery_full;
      case 'CHARGING':
        return Icons.battery_charging_full;
      case 'RESERVED':
        return Icons.lock;
      case 'OCCUPIED':
        return Icons.battery_5_bar;
      case 'SWAPPED_OUT':
        return Icons.battery_2_bar;
      default:
        return Icons.battery_unknown;
    }
  }
}
