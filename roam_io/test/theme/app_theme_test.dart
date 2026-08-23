/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 23 August 2026
 * Description:
 *   Tests app-wide theme configuration values used by light and dark mode.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/theme/app_colours.dart';
import 'package:roam_io/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('darkTheme configures dark colours and text styles', () {
      final theme = AppTheme.darkTheme;

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppColors.sage);
      expect(theme.colorScheme.secondary, AppColors.clay);
      expect(theme.colorScheme.surface, const Color(0xFF171A20));
      expect(theme.scaffoldBackgroundColor, const Color(0xFF101216));
      expect(theme.textTheme.headlineLarge?.color, const Color(0xFFECE7DC));
      expect(theme.textTheme.titleLarge?.fontWeight, FontWeight.w600);
      expect(theme.textTheme.bodySmall?.color, const Color(0xFFB5B0A6));
      expect(theme.textTheme.labelMedium?.color, const Color(0xFF9EB58D));
    });

    test('darkTheme configures card and switch themes', () {
      final theme = AppTheme.darkTheme;
      final cardTheme = theme.cardTheme;
      final switchTheme = theme.switchTheme;

      expect(cardTheme.color, const Color(0xFF171A20));
      expect(cardTheme.elevation, 0);
      expect(cardTheme.shape, isA<RoundedRectangleBorder>());

      expect(
        switchTheme.thumbColor?.resolve({WidgetState.selected}),
        Colors.white,
      );
      expect(switchTheme.thumbColor?.resolve({}), const Color(0xFFB5B0A6));
      expect(
        switchTheme.trackColor?.resolve({WidgetState.selected}),
        AppColors.sage,
      );
      expect(switchTheme.trackColor?.resolve({}), const Color(0xFF30343D));
    });
  });
}
