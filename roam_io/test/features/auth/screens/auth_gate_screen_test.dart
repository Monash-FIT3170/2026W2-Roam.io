/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 04/08/2026
 * Description:
 *   Widget tests routing AuthGateScreen to login, verify email, or main shell.
 */

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/auth/screens/auth_gate_screen.dart';
import 'package:roam_io/features/auth/screens/login_screen.dart';
import 'package:roam_io/features/auth/screens/verify_email_screen.dart';
import 'package:roam_io/features/journeys/data/journey_controller.dart';
import 'package:roam_io/features/navigation/screens/main_shell_screen.dart';
import 'package:roam_io/features/onboarding/screens/onboarding_screen.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';
import 'package:roam_io/notifications/notification.dart';

import '../../../support/fake_firebase_user.dart';
import '../../../support/journey_test_harness.dart';

void main() {
  // MainShellScreen initialises Firebase-dependent map widgets.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  });

  group('AuthGateScreen', () {
    testWidgets('shows login when unauthenticated', (tester) async {
      final repo = _AuthGateRepository(user: null);
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => AuthProvider(authRepository: repo),
            child: const AuthGateScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('shows verify email when signed in but not verified', (
      tester,
    ) async {
      final user = FakeFirebaseUser(
        uid: 'u1',
        email: 'a@b.com',
        emailVerified: false,
      );
      final repo = _AuthGateRepository(
        user: user,
        profile: ProfileModel.fromMap({
          'uid': 'u1',
          'onboardingCompleted': false,
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => AuthProvider(authRepository: repo),
            child: const AuthGateScreen(requestNotificationPermission: false),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(find.byType(VerifyEmailScreen), findsOneWidget);
    });

    for (final skip in [true, false]) {
      testWidgets(
        'new account ${skip ? 'skips' : 'finishes'} once, then opens Home',
        (tester) async {
          final repo = _AuthGateRepository(
            user: FakeFirebaseUser(
              uid: 'new',
              email: 'new@example.com',
              emailVerified: true,
            ),
            profile: ProfileModel.fromMap({
              'uid': 'new',
              'onboardingCompleted': false,
            }),
          );
          final auth = AuthProvider(authRepository: repo);
          addTearDown(auth.dispose);
          await tester.pumpWidget(
            MaterialApp(
              home: MultiProvider(
                providers: [
                  ChangeNotifierProvider.value(value: auth),
                  ChangeNotifierProvider<JourneyController>(
                    create: (_) => JourneyTestController(),
                  ),
                ],
                child: const AuthGateScreen(
                  requestNotificationPermission: false,
                ),
              ),
            ),
          );
          await tester.pump(const Duration(seconds: 2));
          await tester.pumpAndSettle();
          expect(find.byType(OnboardingScreen), findsOneWidget);
          expect(find.byType(MainShellScreen), findsNothing);
          if (!skip) {
            for (var i = 0; i < 5; i++) {
              await tester.tap(find.text('Next chapter'));
              await tester.pumpAndSettle();
            }
          }
          await tester.tap(find.text(skip ? 'Skip tour' : 'Let’s roam'));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(find.byType(OnboardingScreen), findsNothing);
          expect(
            tester
                .widget<MainShellScreen>(find.byType(MainShellScreen))
                .initialIndex,
            0,
          );
          expect(repo.completionWrites, 1);
          expect(auth.currentProfile!.onboardingCompleted, isTrue);
          await auth.refreshCurrentUser();
          await tester.pump();
          expect(find.byType(OnboardingScreen), findsNothing);
        },
      );
    }

    testWidgets('save failure keeps tutorial open and supports retry', (
      tester,
    ) async {
      final repo = _AuthGateRepository(
        user: FakeFirebaseUser(
          uid: 'new',
          email: 'new@example.com',
          emailVerified: true,
        ),
        profile: ProfileModel.fromMap({
          'uid': 'new',
          'onboardingCompleted': false,
        }),
      )..failCompletion = true;
      final auth = AuthProvider(authRepository: repo);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: auth,
            child: const AuthGateScreen(requestNotificationPermission: false),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip tour'));
      await tester.pumpAndSettle();
      expect(
        find.text('Couldn’t save your progress. Please try again.'),
        findsOneWidget,
      );
      expect(auth.currentProfile!.onboardingCompleted, isFalse);
      await tester.tap(find.text('Skip tour'));
      await tester.pumpAndSettle();
      expect(repo.completionWrites, 2);
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('missing profile cannot bypass first-time onboarding', (
      tester,
    ) async {
      final repo = _AuthGateRepository(
        user: FakeFirebaseUser(
          uid: 'new',
          email: 'new@example.com',
          emailVerified: true,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => AuthProvider(authRepository: repo),
            child: const AuthGateScreen(requestNotificationPermission: false),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(MainShellScreen), findsNothing);
      expect(find.text('We couldn’t load your profile.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('shows main shell when signed in and verified', (tester) async {
      final user = FakeFirebaseUser(
        uid: 'u1',
        email: 'a@b.com',
        emailVerified: true,
      );
      final now = DateTime(2026, 5, 1);
      final profile = ProfileModel(
        uid: 'u1',
        username: 't',
        displayName: 'T',
        email: 'a@b.com',
        createdAt: now,
        updatedAt: now,
      );
      final repo = _AuthGateRepository(user: user, profile: profile);
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
            child: const AuthGateScreen(requestNotificationPermission: false),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(find.byType(NotificationOverlay), findsOneWidget);
      expect(find.byType(MainShellScreen), findsOneWidget);
    });
  });
}

/// Configurable auth repository for exercising each AuthGate branch.
class _AuthGateRepository implements AuthRepository {
  _AuthGateRepository({
    required firebase_auth.User? user,
    ProfileModel? profile,
  }) : _user = user,
       _profile = profile;

  final firebase_auth.User? _user;
  ProfileModel? _profile;
  int completionWrites = 0;
  bool failCompletion = false;

  @override
  Future<void> completeOnboarding() async {
    completionWrites++;
    if (failCompletion) throw StateError('Offline');
    _profile = _profile!.copyWith(onboardingCompleted: true);
  }

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
