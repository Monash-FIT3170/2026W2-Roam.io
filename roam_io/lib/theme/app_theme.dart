import 'package:flutter/material.dart';
import 'app_colours.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,

    colorScheme: const ColorScheme.light(
      primary: AppColors.sage,
      secondary: AppColors.clay,
      surface: AppColors.cream,
      background: AppColors.cream,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.ink,
      onBackground: AppColors.ink,
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

      bodySmall: const TextStyle(
        fontSize: 12,
        color: Colors.grey,
      ),

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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),
  );
}