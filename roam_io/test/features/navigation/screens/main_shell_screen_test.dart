/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 04/08/2026
 * Description:
 *   Widget tests for main shell tab switching and journeys screen content.
 */

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/journeys/screens/journeys_screen.dart';
import 'package:roam_io/features/navigation/screens/main_shell_screen.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';

import '../../../support/fake_firebase_user.dart';

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
    // Arrange: provide an authenticated user and profile.
    final repository = _MainShellAuthRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(authRepository: repository),
          child: const MainShellScreen(
            // Android platform permissions are not available in widget tests.
            requestNotificationPermission: false,
          ),
        ),
      ),
    );

    // Allow the shell and Firebase-backed tab widgets to initialise.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // IndexedStack keeps inactive tabs mounted but offstage.
    expect(find.byType(JourneysScreen, skipOffstage: false), findsOneWidget);

    // Act: switch from the default Map tab to Journeys.
    await tester.tap(find.text('JOURNEYS'));
    await tester.pumpAndSettle();

    // Assert: Journeys content is now visible.
    expect(find.text('32 XP earned'), findsOneWidget);
  });
}

/// Signed-in user with profile so the shell can render authenticated tabs.
class _MainShellAuthRepository implements AuthRepository {
  _MainShellAuthRepository()
    : _user = FakeFirebaseUser(
        uid: 'shell-user',
        email: 'shell@test.com',
        emailVerified: true,
      ),
      _profile = ProfileModel(
        uid: 'shell-user',
        username: 'shell',
        displayName: 'Shell User',
        email: 'shell@test.com',
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
      );

  final firebase_auth.User _user;
  final ProfileModel _profile;

  @override
  Stream<firebase_auth.User?> authStateChanges() async* {
    yield _user;
  }

  @override
  firebase_auth.User? get currentUser => _user;

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<ProfileModel?> getCurrentUserProfile() async => _profile;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
