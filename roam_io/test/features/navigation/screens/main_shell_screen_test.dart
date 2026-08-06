/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Widget tests for main shell tab switching, Home friend feed stubs, and
 *   notification action toast feedback.
 */

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/map/data/map_page.dart';
import 'package:roam_io/features/navigation/screens/main_shell_screen.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';
import 'package:roam_io/notifications/notification.dart';
import 'package:roam_io/shared/widgets/app_toast.dart';

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

  testWidgets('starts on map tab and opens the new top-level destinations', (
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

    expect(find.byType(MapPage), findsOneWidget);
    expect(find.byTooltip('Test notification'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.text('HOME'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Amar'), findsOneWidget);
    expect(find.text('Sidequest with Mates'), findsOneWidget);
    expect(find.text('Journeys'), findsNothing);
    expect(find.text('Quests'), findsNothing);

    await tester.tap(find.text('SOCIAL'));
    await tester.pumpAndSettle();
    expect(find.text('Social hub'), findsOneWidget);

    await tester.tap(find.text('YOU'));
    await tester.pumpAndSettle();
    expect(find.text('Most Visited Location'), findsOneWidget);

    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Preferences'), findsOneWidget);
  });

  for (final scenario in [
    (
      action: const NotificationAction(
        type: NotificationActionType.accept,
        label: 'Accept',
      ),
      expectedMessage: 'Friend request accepted.',
    ),
    (
      action: const NotificationAction(
        type: NotificationActionType.decline,
        label: 'Decline',
      ),
      expectedMessage: 'Friend request declined.',
    ),
  ]) {
    testWidgets(
      '${scenario.action.label.toLowerCase()} notification action shows app toast',
      (tester) async {
        final repository = _MainShellAuthRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<AuthProvider>(
              create: (_) => AuthProvider(authRepository: repository),
              child: const MainShellScreen(
                requestNotificationPermission: false,
              ),
            ),
          ),
        );

        await tester.pump();

        NotificationService.instance.handleAction(
          notification: AppNotification(
            id: 'friend-request-1',
            type: NotificationType.friendRequest,
            title: 'New Friend Request',
            body: 'Alex sent you a friend request.',
            timestamp: DateTime(2026, 8, 5),
          ),
          action: scenario.action,
        );

        await tester.pump();

        expect(find.byType(AppToastBanner), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
        expect(find.text(scenario.expectedMessage), findsOneWidget);
      },
    );
  }
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
