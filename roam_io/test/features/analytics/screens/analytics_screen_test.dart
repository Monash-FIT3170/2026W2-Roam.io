import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/analytics/screens/analytics_screen.dart';

void main() {
  testWidgets('renders analytics header and stat labels', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AnalyticsScreen())),
    );

    expect(find.text('Your Analytics'), findsOneWidget);
    expect(find.text('Activity Map'), findsOneWidget);
    expect(find.text('XP Count'), findsOneWidget);
    expect(find.text('Tiles Visited'), findsOneWidget);
  });
}
