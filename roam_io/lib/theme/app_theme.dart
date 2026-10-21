/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 1/05/2026
 * Description:
 *   Defines the app-wide light and dark Material theme configuration for
 *   Roam.io.
 */

import 'package:flutter/material.dart';
import 'app_accessibility.dart';
import 'app_colours.dart';

/// Builds the light and dark `ThemeData` used by the root app.
class AppTheme {
  /// Light mode Material theme.
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    materialTapTargetSize: MaterialTapTargetSize.padded,

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
    materialTapTargetSize: MaterialTapTargetSize.padded,
    brightness: Brightness.dark,

    colorScheme: const ColorScheme.dark(
      primary: AppColors.sage,
      secondary: AppColors.clay,
      surface: AppColors.darkSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFFECE7DC),
    ),

    scaffoldBackgroundColor: AppColors.darkBackground,

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
      backgroundColor: AppColors.darkSurface,
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.clay,
      foregroundColor: Colors.white,
    ),

    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
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
        return AppColors.darkElevated;
      }),
    ),
  );

  /// Light theme with AA-or-better contrast on every text and control colour.
  static final ThemeData highContrastLightTheme = _highContrast(
    base: lightTheme,
    scheme: const ColorScheme.light(
      primary: Color(0xFF38502D),
      secondary: Color(0xFF8A311C),
      surface: Color(0xFFFFFFFF),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF000000),
      outline: Color(0xFF000000),
      error: Color(0xFF8C0000),
    ),
  );

  /// Dark theme with AA-or-better contrast on every text and control colour.
  static final ThemeData highContrastDarkTheme = _highContrast(
    base: darkTheme,
    scheme: const ColorScheme.dark(
      primary: Color(0xFFC4DBB2),
      secondary: Color(0xFFFFB09C),
      surface: Color(0xFF000000),
      onPrimary: Color(0xFF000000),
      onSecondary: Color(0xFF000000),
      onSurface: Color(0xFFFFFFFF),
      outline: Color(0xFFFFFFFF),
      error: Color(0xFFFFB4AB),
    ),
  );

  /// Heavier weights so thin text stays legible in High Contrast.
  static TextTheme _bolder(TextTheme t) {
    TextStyle? bold(TextStyle? s) => s?.copyWith(
      fontWeight: (s.fontWeight?.value ?? 400) < 600
          ? FontWeight.w700
          : s.fontWeight,
    );
    return t.copyWith(
      bodyLarge: bold(t.bodyLarge),
      bodyMedium: bold(t.bodyMedium),
      bodySmall: bold(t.bodySmall),
      labelLarge: bold(t.labelLarge),
      labelMedium: bold(t.labelMedium),
      labelSmall: bold(t.labelSmall),
      titleSmall: bold(t.titleSmall),
    );
  }

  static ThemeData _highContrast({
    required ThemeData base,
    required ColorScheme scheme,
  }) {
    final background = scheme.surface;
    final textTheme = _bolder(
      base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
    );
    final labelMedium = textTheme.labelMedium?.copyWith(color: scheme.primary);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme.copyWith(labelMedium: labelMedium),
      dividerColor: scheme.outline,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [...base.extensions.values, const HighContrastExtension()],
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurface,
        backgroundColor: background,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.secondary,
        foregroundColor: scheme.onSecondary,
      ),
      cardTheme: CardThemeData(
        color: background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outline, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1.5),
      iconTheme: IconThemeData(color: scheme.onSurface),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          side: BorderSide(color: scheme.outline, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          side: BorderSide(color: scheme.outline, width: 2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline, width: 2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: scheme.onSurface),
        hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.75)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 3),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.8),
        indicatorColor: scheme.primary,
        dividerColor: scheme.outline,
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: scheme.outline, width: 1.5),
        labelStyle: TextStyle(color: scheme.onSurface),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outline, width: 2),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: background,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: scheme.outline, width: 2),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.outline.withValues(alpha: 0.35),
        thumbColor: scheme.onSurface,
        trackHeight: 6,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.outline.withValues(alpha: 0.35),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(scheme.onSurface),
        trackOutlineColor: WidgetStatePropertyAll(scheme.outline),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : background,
        ),
      ),
    );
  }
}
