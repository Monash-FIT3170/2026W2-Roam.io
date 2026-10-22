/*
 * Description:
 *   With the device Reduce Motion flag on, route transitions (including the
 *   app's CupertinoPageRoute-based forward navigation) finish almost at once.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/shared/widgets/app_page_transition.dart';
import 'package:roam_io/theme/app_accessibility.dart';

Future<void> _pushAndMeasure(
  WidgetTester tester,
  Route<void> Function(WidgetBuilder builder) routeFor,
) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      builder: (context, child) =>
          AppAccessibility.wrap(context, child, largerText: false),
      home: const Scaffold(body: Text('home')),
    ),
  );

  navigatorKey.currentState!.push(
    routeFor((_) => const Scaffold(body: Text('details'))),
  );
  await tester.pump();
  // One short frame is enough when transitions are collapsed.
  await tester.pump(const Duration(milliseconds: 60));
}

void main() {
  Future<void> setReduceMotion(WidgetTester tester, bool value) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: value);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  testWidgets('forward Cupertino route settles in one short frame', (
    tester,
  ) async {
    await setReduceMotion(tester, true);
    await _pushAndMeasure(
      tester,
      (builder) => appHorizontalPageRoute<void>(builder: builder),
    );
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('details'), findsOneWidget);
  });

  testWidgets('Material route settles in one short frame', (tester) async {
    await setReduceMotion(tester, true);
    await _pushAndMeasure(
      tester,
      (builder) => MaterialPageRoute<void>(builder: builder),
    );
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('details'), findsOneWidget);
  });

  testWidgets('routes still animate when Reduce Motion is off', (tester) async {
    await setReduceMotion(tester, false);
    await _pushAndMeasure(
      tester,
      (builder) => appHorizontalPageRoute<void>(builder: builder),
    );
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
  });
}
