import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/theme/app_theme_mode.dart';

void main() {
  group('AppThemeMode storage', () {
    test('round-trips every supported value', () {
      for (final mode in AppThemeMode.values) {
        expect(AppThemeMode.fromStorage(mode.storageValue), mode);
      }
    });

    test('migrates the legacy dark mode flag when no new value exists', () {
      expect(
        AppThemeMode.fromStorage(null, legacyDarkModeEnabled: true),
        AppThemeMode.dark,
      );
      expect(
        AppThemeMode.fromStorage(null, legacyDarkModeEnabled: false),
        AppThemeMode.light,
      );
    });

    test('falls back safely when the stored value is invalid', () {
      expect(AppThemeMode.fromStorage('sepia'), AppThemeMode.light);
      expect(
        AppThemeMode.fromStorage('sepia', legacyDarkModeEnabled: true),
        AppThemeMode.dark,
      );
    });
  });

  group('DynamicThemeSchedule', () {
    test('uses light appearance from 6 AM until 6 PM', () {
      expect(
        AppThemeMode.dynamic.resolve(DateTime(2026, 8, 17, 5, 59)),
        ThemeMode.dark,
      );
      expect(
        AppThemeMode.dynamic.resolve(DateTime(2026, 8, 17, 6)),
        ThemeMode.light,
      );
      expect(
        AppThemeMode.dynamic.resolve(DateTime(2026, 8, 17, 17, 59)),
        ThemeMode.light,
      );
      expect(
        AppThemeMode.dynamic.resolve(DateTime(2026, 8, 17, 18)),
        ThemeMode.dark,
      );
    });

    test('fixed preferences ignore the clock', () {
      final midnight = DateTime(2026, 8, 17);
      final noon = DateTime(2026, 8, 17, 12);

      expect(AppThemeMode.light.resolve(midnight), ThemeMode.light);
      expect(AppThemeMode.light.resolve(noon), ThemeMode.light);
      expect(AppThemeMode.dark.resolve(midnight), ThemeMode.dark);
      expect(AppThemeMode.dark.resolve(noon), ThemeMode.dark);
    });

    test('returns the next local transition boundary', () {
      expect(
        DynamicThemeSchedule.nextTransitionAfter(DateTime(2026, 8, 17, 5, 59)),
        DateTime(2026, 8, 17, 6),
      );
      expect(
        DynamicThemeSchedule.nextTransitionAfter(DateTime(2026, 8, 17, 6)),
        DateTime(2026, 8, 17, 18),
      );
      expect(
        DynamicThemeSchedule.nextTransitionAfter(DateTime(2026, 8, 17, 18)),
        DateTime(2026, 8, 18, 6),
      );
    });
  });
}
