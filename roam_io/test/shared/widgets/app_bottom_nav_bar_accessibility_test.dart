/*
 * Description:
 *   The bottom navigation bar keeps its labels inside their slots at large text
 *   sizes, drops its motion under Reduce Motion, and exposes each tab to
 *   screen readers as a selectable button.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/shared/widgets/app_bottom_nav_bar.dart';

import '../../support/accessibility_harness.dart';

Widget _bar({int currentIndex = 0}) => Scaffold(
  bottomNavigationBar: AppBottomNavBar(
    currentIndex: currentIndex,
    onTap: (_) {},
  ),
);

void main() {
  testAccessibleLayouts('bottom nav bar lays out', (
    tester,
    theme,
    scale,
  ) async {
    await pumpAccessible(
      tester,
      _bar(currentIndex: 4),
      theme: theme,
      textScale: scale,
      largerText: true,
    );
  });

  testWidgets('labels stop growing past the clamp', (tester) async {
    await pumpAccessible(tester, _bar(), textScale: 3.0, largerText: true);

    final settings = tester.widget<Text>(find.text('SETTINGS'));
    final context = tester.element(find.text('SETTINGS'));
    final scaler = MediaQuery.textScalerOf(context);
    expect(settings.data, 'SETTINGS');
    expect(scaler.scale(10), lessThanOrEqualTo(10 * 1.3 + 0.001));
  });

  testWidgets('each tab is a button with a selected state', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpAccessible(tester, _bar(currentIndex: 1));

    expect(
      tester.getSemantics(find.text('SOCIAL')),
      matchesSemantics(
        label: 'SOCIAL',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
        hasEnabledState: false,
      ),
    );
    handle.dispose();
  });
}
