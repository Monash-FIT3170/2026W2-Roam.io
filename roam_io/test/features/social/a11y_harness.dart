/*
 * Description:
 *   Shared harness for Larger Text / High Contrast layout tests: pumps a screen
 *   at 2x system text with the Larger Text boost across all four app themes.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/theme/app_accessibility.dart';
import 'package:roam_io/theme/app_theme.dart';

Map<String, ThemeData> a11yThemes() => <String, ThemeData>{
  'light': AppTheme.lightTheme,
  'dark': AppTheme.darkTheme,
  'high contrast light': AppTheme.highContrastLightTheme,
  'high contrast dark': AppTheme.highContrastDarkTheme,
};

/// A MaterialApp with 2x system text, the Larger Text boost and [theme].
Widget a11yApp(ThemeData theme, Widget home) {
  return MediaQuery(
    data: const MediaQueryData(
      size: Size(390, 844),
      textScaler: TextScaler.linear(2.0),
    ),
    child: MaterialApp(
      theme: theme,
      builder: (context, child) =>
          AppAccessibility.wrap(context, child, largerText: true),
      home: home,
    ),
  );
}

void useA11yPhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Registers one test per app theme that runs [body] and then asserts that
/// nothing (such as a RenderFlex overflow) was thrown during layout.
void a11yMatrix(
  String description,
  Future<void> Function(WidgetTester tester, ThemeData theme) body,
) {
  for (final entry in a11yThemes().entries) {
    testWidgets('$description: ${entry.key}, 2x text', (tester) async {
      useA11yPhoneView(tester);
      final original = FlutterError.onError;
      final errors = <String>[];
      FlutterError.onError = (details) {
        final info = details.informationCollector
            ?.call()
            .map((node) => node.toStringDeep())
            .join('\n');
        final head = (info ?? '').split('\n').take(3).join(' ');
        errors.add('${details.exception} | $head');
      };
      try {
        await body(tester, entry.value);
      } finally {
        FlutterError.onError = original;
      }
      expect(tester.takeException(), isNull);
      expect(errors, isEmpty);
    });
  }
}

/// Scrolls the first scrollable to its end so lower rows get laid out.
Future<void> scrollToEnd(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isEmpty) return;
  await tester.drag(scrollable.first, const Offset(0, -4000));
  await tester.pumpAndSettle();
}
