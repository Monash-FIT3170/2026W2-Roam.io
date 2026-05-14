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

    await tester.tap(find.text('QUESTS'));
    expect(taps, [1]);

    await tester.tap(find.text('ANALYTICS'));
    expect(taps, [1, 3]);
  });

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
