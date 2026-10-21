/*
 * Description:
 *   Reduce Motion: the saved-activity celebration drops its particle burst but
 *   still confirms the save and dismisses.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/shared/widgets/activity_saved_celebration.dart';

Finder get _particlePaint => find.byWidgetPredicate(
  (widget) =>
      widget is CustomPaint &&
      widget.painter.runtimeType.toString() == '_SavedParticlePainter',
);

Future<void> _pump(WidgetTester tester, {required bool reduceMotion}) {
  return tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(
        home: ActivitySavedCelebration(xpEarned: 120, onDismiss: () {}),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the particle burst when motion is allowed', (
    tester,
  ) async {
    await _pump(tester, reduceMotion: false);
    expect(_particlePaint, findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('omits the particle burst but keeps the confirmation', (
    tester,
  ) async {
    await _pump(tester, reduceMotion: true);

    expect(_particlePaint, findsNothing);
    expect(find.text('Activity Saved'), findsOneWidget);
    expect(find.text('+120 XP'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
