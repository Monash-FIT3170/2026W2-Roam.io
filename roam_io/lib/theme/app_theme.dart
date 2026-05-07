/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 1/05/2026
 * Description:
 *   Defines the app-wide light and dark Material theme configuration for
 *   Roam.io.
 */

import 'package:flutter/material.dart';
import 'app_colours.dart';

/// Builds the light and dark `ThemeData` used by the root app.
class AppTheme {
  /// Light mode Material theme.
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,

    colorScheme: const ColorScheme.light(
      primary: AppColors.sage,
      secondary: AppColors.clay,
      surface: AppColors.cream,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.ink,
    ),

    scaffoldBackgroundColor: AppColors.cream,

    textTheme: ThemeData.light().textTheme.copyWith(
      headlineLarge: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppColors.ink,
      ),

      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),

      titleMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),

      bodyMedium: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
      ),

      bodySmall: const TextStyle(fontSize: 12, color: Colors.grey),

      labelMedium: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.sage,
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: AppColors.sage,
      unselectedItemColor: AppColors.ink,
      backgroundColor: AppColors.cream,
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.clay,
      foregroundColor: Colors.white,
    ),

    cardTheme: CardThemeData(
      color: AppColors.cream,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );

  /// Dark mode Material theme.
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    colorScheme: const ColorScheme.dark(
      primary: AppColors.sage,
      secondary: AppColors.clay,
      surface: Color(0xFF171A20),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFFECE7DC),
    ),

    scaffoldBackgroundColor: const Color(0xFF101216),

    textTheme: ThemeData.dark().textTheme.copyWith(
      headlineLarge: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Color(0xFFECE7DC),
      ),

      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Color(0xFFECE7DC),
      ),

      titleMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFFECE7DC),
      ),

      bodyMedium: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Color(0xFFECE7DC),
      ),

      bodySmall: const TextStyle(fontSize: 12, color: Color(0xFFB5B0A6)),

      labelMedium: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF9EB58D),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: Color(0xFF9EB58D),
      unselectedItemColor: Color(0xFFB5B0A6),
      backgroundColor: Color(0xFF171A20),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.clay,
      foregroundColor: Colors.white,
    ),

    cardTheme: CardThemeData(
      color: const Color(0xFF171A20),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return const Color(0xFFB5B0A6);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.sage;
        }
        return const Color(0xFF30343D);
      }),
    ),
  );
}
