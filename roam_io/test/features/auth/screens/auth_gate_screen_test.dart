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
import 'package:roam_io/features/navigation/screens/main_shell_screen.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';

import '../../../support/fake_firebase_user.dart';

void main() {
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
      final repo = _AuthGateRepository(user: user);
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => AuthProvider(authRepository: repo),
            child: const AuthGateScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(VerifyEmailScreen), findsOneWidget);
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
          home: ChangeNotifierProvider(
            create: (_) => AuthProvider(authRepository: repo),
            child: const AuthGateScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(MainShellScreen), findsOneWidget);
    });
  });
}

class _AuthGateRepository implements AuthRepository {
  _AuthGateRepository({required firebase_auth.User? user, ProfileModel? profile})
    : _user = user,
      _profile = profile;

  final firebase_auth.User? _user;
  final ProfileModel? _profile;

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
