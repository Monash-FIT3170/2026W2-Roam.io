/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 5 August 2026
 * Description:
 *   Widget tests for Home, Social, Map, You, and Settings bottom navigation.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/shared/widgets/app_bottom_nav_bar.dart';

void main() {
  testWidgets('invokes onTap with the tapped tab index', (tester) async {
    final taps = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppBottomNavBar(currentIndex: 2, onTap: taps.add)),
      ),
    );

    await tester.tap(find.text('SOCIAL'));
    expect(taps, [1]);

    await tester.tap(find.text('YOU'));
    expect(taps, [1, 3]);

    await tester.tap(find.text('SETTINGS'));
    expect(taps, [1, 3, 4]);
  });

  // The centre MAP tab is index 2 even though it is rendered between other tabs.
  testWidgets('floating map tab reports index 2', (tester) async {
    final taps = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppBottomNavBar(currentIndex: 0, onTap: taps.add)),
      ),
    );

    await tester.tap(find.text('MAP'));
    expect(taps, [2]);
  });
}
