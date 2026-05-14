import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/quests/screens/quests_screen.dart';

void main() {
  testWidgets('renders quests header and placeholder', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: QuestsScreen())),
    );

    expect(find.text('Quests'), findsOneWidget);
    expect(find.text('Quest content goes here'), findsOneWidget);
  });
}
