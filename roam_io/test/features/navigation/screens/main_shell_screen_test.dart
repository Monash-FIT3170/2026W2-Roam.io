/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 17/05/2026
 * Description:
 *   Widget tests for main shell tab switching and journeys screen content.
 */

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/journeys/data/journey_controller.dart';
import 'package:roam_io/features/journeys/screens/journeys_screen.dart';
import 'package:roam_io/features/navigation/screens/main_shell_screen.dart';

import '../../../support/journey_test_harness.dart';

void main() {
  // Map tab loads Firebase-backed widgets during the first pump.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  });

  testWidgets('starts on map tab and switches to journeys when tapped', (
    tester,
  ) async {
    final repo = JourneyTestAuthRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => AuthProvider(authRepository: repo),
            ),
            ChangeNotifierProvider<JourneyController>(
              create: (_) => JourneyTestController(),
            ),
          ],
          child: const MainShellScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // IndexedStack keeps offstage tabs in the tree; include them in finders.
    expect(find.byType(JourneysScreen, skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('JOURNEYS'));
    await tester.pumpAndSettle();

    expect(find.text('32 XP earned'), findsOneWidget);
  });
}
