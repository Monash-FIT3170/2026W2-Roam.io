/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 5 August 2026
 * Description:
 *   Widget tests for the Social destination foundation.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/social/screens/social_screen.dart';

void main() {
  testWidgets('shows the social foundation page without fake actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SocialScreen())),
    );

    expect(find.text('Social'), findsOneWidget);
    expect(find.text('Social hub'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });
}
