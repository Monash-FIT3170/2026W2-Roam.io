/*
 * Description:
 *   Shared helpers for layout tests under Larger Text, High Contrast, and
 *   2x system text scale on a phone-sized view.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/theme/app_accessibility.dart';
import 'package:roam_io/theme/app_theme.dart';

/// The four themes every accessibility layout test runs against.
Map<String, ThemeData> get accessibilityThemes => <String, ThemeData>{
  'light': AppTheme.lightTheme,
  'dark': AppTheme.darkTheme,
  'high contrast light': AppTheme.highContrastLightTheme,
  'high contrast dark': AppTheme.highContrastDarkTheme,
};

/// Pumps [home] inside the app's accessibility wrapper on a 390x844 view.
Future<void> pumpAccessible(
  WidgetTester tester,
  Widget home, {
  ThemeData? theme,
  double textScale = 1.0,
  bool largerText = false,
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        textScaler: TextScaler.linear(textScale),
        disableAnimations: disableAnimations,
      ),
      child: MaterialApp(
        theme: theme,
        builder: (context, child) =>
            AppAccessibility.wrap(context, child, largerText: largerText),
        home: home,
      ),
    ),
  );
  await tester.pump();
}

/// Runs [body] once per theme at 1x and at 2x system text with Larger Text on.
void testAccessibleLayouts(
  String description,
  Future<void> Function(WidgetTester tester, ThemeData theme, double scale)
  body,
) {
  for (final entry in accessibilityThemes.entries) {
    for (final scale in <double>[1.0, 2.0]) {
      testWidgets('$description: ${entry.key} at ${scale}x text', (
        tester,
      ) async {
        // Collect errors ourselves so a failure names the overflowing widget.
        final errors = <String>[];
        final original = FlutterError.onError;
        FlutterError.onError = (details) => errors.add(details.toString());
        try {
          await body(tester, entry.value, scale);
        } finally {
          FlutterError.onError = original;
        }
        expect(errors, isEmpty, reason: errors.join('\n---\n'));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
