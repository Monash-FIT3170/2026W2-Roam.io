/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 5 August 2026
 * Description:
 *   Widget tests for Settings navigation, sign-out, and account edit flows.
 */

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
import 'package:roam_io/features/settings/screens/change_display_name_screen.dart';
import 'package:roam_io/features/settings/screens/change_email_screen.dart';
import 'package:roam_io/features/settings/screens/change_username_screen.dart';
import 'package:roam_io/features/settings/screens/settings_screen.dart';

import '../../../support/fake_firebase_user.dart';

void main() {
  // SettingsScreen reads Firebase-backed auth state on first build.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  });

  testWidgets('navigates to change password screen', (tester) async {
    final repo = _SettingsActionsRepository();
    final provider = AuthProvider(authRepository: repo);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pump();
    await tester.pump();

    // Settings actions sit below the fold in a scrollable column.
    final changePassword = find.text('Change Password');
    await tester.ensureVisible(changePassword);
    await tester.tap(changePassword);
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordScreen), findsOneWidget);
    provider.dispose();
  });

  testWidgets('account rows do not duplicate current profile values', (
    tester,
  ) async {
    final repo = _SettingsActionsRepository();
    final provider = AuthProvider(authRepository: repo);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Change Display Name'), findsOneWidget);
    expect(find.text('Change Username'), findsOneWidget);
    expect(find.text('Change Email'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);

    expect(find.text('Traveller'), findsOneWidget);
    expect(find.text('@traveller'), findsOneWidget);
    expect(find.text('traveller'), findsNothing);
    expect(find.text('traveller@example.com'), findsNothing);
    expect(
      find.text('Email changes require verification before taking effect.'),
      findsNothing,
    );

    provider.dispose();
  });

  testWidgets('sign out invokes repository signOut', (tester) async {
    final repo = _SettingsActionsRepository();
    final provider = AuthProvider(authRepository: repo);

    // Provider must wrap MaterialApp so pushed routes can read AuthProvider.
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pump();
    await tester.pump();

    final logOut = find.text('Log out');
    await tester.ensureVisible(logOut);
    final logOutCenter = find.ancestor(
      of: logOut,
      matching: find.byType(Center),
    );
    expect(logOutCenter, findsOneWidget);
    await tester.tap(logOut);
    await tester.pumpAndSettle();

    expect(repo.signOutCalls, 1);
    provider.dispose();
  });

  testWidgets('navigates to account edit screens from Settings rows', (
    tester,
  ) async {
    final repo = _SettingsActionsRepository();
    final provider = AuthProvider(authRepository: repo);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Change Display Name'));
    await tester.pumpAndSettle();
    expect(find.byType(ChangeDisplayNameScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(ChangeDisplayNameScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Change Username'));
    await tester.pumpAndSettle();
    expect(find.byType(ChangeUsernameScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(ChangeUsernameScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Change Email'));
    await tester.pumpAndSettle();
    expect(find.byType(ChangeEmailScreen), findsOneWidget);

    provider.dispose();
  });

  testWidgets('display name screen validates empty values', (tester) async {
    final repo = _SettingsActionsRepository(
      profile: _buildProfile(displayName: '-'),
    );
    final provider = AuthProvider(authRepository: repo);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Change Display Name'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '');
    await tester.tap(find.text('Save Display Name'));
    await tester.pump();

    expect(find.text('Display name is required.'), findsOneWidget);
    provider.dispose();
  });

  testWidgets('username screen saves through provider and shows toast', (
    tester,
  ) async {
    final repo = _SettingsActionsRepository();
    final provider = AuthProvider(authRepository: repo);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: const MaterialApp(home: ChangeUsernameScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextFormField), 'newtraveller');
    await tester.tap(find.text('Save Username'));
    await tester.pump();

    expect(repo.updatedUsername, 'newtraveller');
    expect(find.text('Username updated.'), findsOneWidget);
    expect(find.byType(ChangeUsernameScreen), findsOneWidget);
    provider.dispose();
  });

  testWidgets('display name screen saves and remains open', (tester) async {
    final repo = _SettingsActionsRepository();
    final provider = AuthProvider(authRepository: repo);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: const MaterialApp(home: ChangeDisplayNameScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Change Display Name'), findsOneWidget);
    expect(find.text('Display Name'), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'Updated Traveller');
    await tester.tap(find.text('Save Display Name'));
    await tester.pump();

    expect(repo.updatedDisplayName, 'Updated Traveller');
    expect(find.text('Display name updated.'), findsOneWidget);
    expect(find.byType(ChangeDisplayNameScreen), findsOneWidget);
    provider.dispose();
  });

  testWidgets('email screen requests verified email change', (tester) async {
    final repo = _SettingsActionsRepository();
    final provider = AuthProvider(authRepository: repo);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: const MaterialApp(home: ChangeEmailScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'new@example.com');
    await tester.enterText(fields.at(1), 'current-password');
    await tester.tap(find.text('Send Verification Email'));
    await tester.pump();

    expect(repo.emailChangePassword, 'current-password');
    expect(repo.emailChangeNewEmail, 'new@example.com');
    expect(
      find.text(
        'We will send you a verification link to your new email address.',
      ),
      findsOneWidget,
    );
    expect(find.text('Verification email sent.'), findsOneWidget);
    expect(find.byType(ChangeEmailScreen), findsOneWidget);
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

class _SettingsActionsRepository implements AuthRepository {
  _SettingsActionsRepository({ProfileModel? profile})
    : _profile = profile ?? _buildProfile(displayName: 'Traveller'),
      _user = FakeFirebaseUser(
        uid: 'user-1',
        email: 'traveller@example.com',
        emailVerified: true,
      );

  final firebase_auth.User _user;
  final ProfileModel _profile;
  int signOutCalls = 0;
  String? updatedDisplayName;
  String? updatedUsername;
  String? emailChangePassword;
  String? emailChangeNewEmail;

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
  Future<void> updateDisplayName(String displayName) async {
    updatedDisplayName = displayName;
  }

  @override
  Future<void> updateUsername(String username) async {
    updatedUsername = username;
  }

  @override
  Future<void> requestEmailChange({
    required String currentPassword,
    required String newEmail,
  }) async {
    emailChangePassword = currentPassword;
    emailChangeNewEmail = newEmail;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
