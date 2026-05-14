import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/auth/screens/change_password_screen.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';
import 'package:roam_io/features/profile/screens/profile_screen.dart';

import '../../../support/fake_firebase_user.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  });

  testWidgets('navigates to change password screen', (tester) async {
    final repo = _ProfileActionsRepository();
    final provider = AuthProvider(authRepository: repo);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: ProfileScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final changePassword = find.text('Change Password');
    await tester.ensureVisible(changePassword);
    await tester.tap(changePassword);
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordScreen), findsOneWidget);
    provider.dispose();
  });

  testWidgets('sign out invokes repository signOut', (tester) async {
    final repo = _ProfileActionsRepository();
    final provider = AuthProvider(authRepository: repo);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: ProfileScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final logOut = find.text('Log out');
    await tester.ensureVisible(logOut);
    await tester.tap(logOut);
    await tester.pumpAndSettle();

    expect(repo.signOutCalls, 1);
    provider.dispose();
  });

  testWidgets('shows snackbar when saving empty display name', (tester) async {
    final repo = _ProfileActionsRepository(
      profile: _buildProfile(displayName: '-'),
    );
    final provider = AuthProvider(authRepository: repo);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: ProfileScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Edit'));
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Enter a name'), findsOneWidget);
    provider.dispose();
  });
}

ProfileModel _buildProfile({required String displayName}) {
  final now = DateTime(2026, 5, 1, 10);
  return ProfileModel(
    uid: 'user-1',
    username: 'traveller',
    displayName: displayName,
    email: 'traveller@example.com',
    createdAt: now,
    updatedAt: now,
    darkModeEnabled: false,
  );
}

class _ProfileActionsRepository implements AuthRepository {
  _ProfileActionsRepository({ProfileModel? profile})
    : _profile = profile ?? _buildProfile(displayName: 'Traveller'),
      _user = FakeFirebaseUser(
        uid: 'user-1',
        email: 'traveller@example.com',
        emailVerified: true,
      );

  final firebase_auth.User _user;
  final ProfileModel _profile;
  int signOutCalls = 0;

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
  Future<void> signOut() async {
    signOutCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
