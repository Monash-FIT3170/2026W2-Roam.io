import 'package:flutter/material.dart';

/// The appearance preference saved with a user's profile.
enum AppThemeMode {
  light,
  dark,
  dynamic;

  /// Stable value written to Firestore.
  String get storageValue => name;

  /// Parses a stored preference, falling back to a legacy dark-mode flag.
  static AppThemeMode fromStorage(
    Object? value, {
    bool legacyDarkModeEnabled = false,
  }) {
    if (value is String) {
      for (final mode in values) {
        if (mode.storageValue == value.toLowerCase()) return mode;
      }
    }

    return legacyDarkModeEnabled ? AppThemeMode.dark : AppThemeMode.light;
  }

  /// Resolves this preference to the binary appearance used by the app, map,
  /// and fog layer.
  ThemeMode resolve(DateTime localTime) {
    return switch (this) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.dynamic =>
        DynamicThemeSchedule.isDaytime(localTime)
            ? ThemeMode.light
            : ThemeMode.dark,
    };
  }
}

/// Local-time schedule used when [AppThemeMode.dynamic] is selected.
///
/// Automotive systems normally use vehicle/ambient information or solar data.
/// The phone app has no vehicle signal, so it uses a predictable local-clock
/// fallback and re-evaluates at each boundary and whenever the app resumes.
abstract final class DynamicThemeSchedule {
  static const int dayStartsAtHour = 6;
  static const int nightStartsAtHour = 18;

  static bool isDaytime(DateTime localTime) {
    return localTime.hour >= dayStartsAtHour &&
        localTime.hour < nightStartsAtHour;
  }

  /// Returns the first day/night boundary strictly after [localTime].
  static DateTime nextTransitionAfter(DateTime localTime) {
    final dayStart = DateTime(
      localTime.year,
      localTime.month,
      localTime.day,
      dayStartsAtHour,
    );
    if (localTime.isBefore(dayStart)) return dayStart;

    final nightStart = DateTime(
      localTime.year,
      localTime.month,
      localTime.day,
      nightStartsAtHour,
    );
    if (localTime.isBefore(nightStart)) return nightStart;

    final tomorrow = localTime.add(const Duration(days: 1));
    return DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      dayStartsAtHour,
    );
  }
}
