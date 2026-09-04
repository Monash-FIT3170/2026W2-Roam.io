import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/shared/widgets/activity_saved_celebration.dart';

void main() {
  testWidgets('renders saved activity confirmation and auto-dismisses', (
    tester,
  ) async {
    var dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ActivitySavedCelebration(
          xpEarned: 120,
          onDismiss: () => dismissed = true,
        ),
      ),
    );

    expect(find.text('Activity Saved'), findsOneWidget);
    expect(find.text('+120 XP'), findsOneWidget);
    expect(find.byIcon(Icons.route_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
  });
}
