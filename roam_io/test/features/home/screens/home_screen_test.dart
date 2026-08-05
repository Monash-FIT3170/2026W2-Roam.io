/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 5 August 2026
 * Description:
 *   Widget tests for the Home destination consolidating Journeys and Quests.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/home/screens/home_screen.dart';

void main() {
  testWidgets(
    'shows journey content by default and quest content when selected',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Journeys'), findsOneWidget);
      expect(find.text('Quests'), findsOneWidget);
      expect(find.text('32 XP earned'), findsOneWidget);

      await tester.tap(find.text('Quests'));
      await tester.pumpAndSettle();

      expect(find.text('Quest content goes here'), findsOneWidget);
    },
  );
}
