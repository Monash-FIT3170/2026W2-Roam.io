/*
 * Author: [Insert Name Here]
 * Last Modified: 9/05/2026
 * Description:
 *   Regression tests for profile screen dark mode toggling preserving profile
 *   data.
 */

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';
import 'package:roam_io/features/profile/screens/profile_screen.dart';

void main() {
  testWidgets('toggling dark mode on preserves existing profile screen data', (
    tester,
  ) async {
    final profile = _buildProfile(darkModeEnabled: false);
    final repository = _FakeAuthRepository(profile);
    final provider = AuthProvider(authRepository: repository);

    await _pumpProfileScreen(tester, provider);
    repository.clearRecordedActions();

    final before = provider.currentProfile!;

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    await tester.pump();

    final after = provider.currentProfile!;

    expect(repository.darkModeUpdates, <bool>[true]);
    expect(after.darkModeEnabled, isTrue);
    expect(after.updatedAt, isNot(before.updatedAt));
    _expectUnrelatedProfileFieldsPreserved(before, after);

    provider.dispose();
  });

  testWidgets('toggling dark mode off preserves existing profile screen data', (
    tester,
  ) async {
    final profile = _buildProfile(darkModeEnabled: true);
    final repository = _FakeAuthRepository(profile);
    final provider = AuthProvider(authRepository: repository);

    await _pumpProfileScreen(tester, provider);
    repository.clearRecordedActions();

    final before = provider.currentProfile!;

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    await tester.pump();

    final after = provider.currentProfile!;

    expect(repository.darkModeUpdates, <bool>[false]);
    expect(after.darkModeEnabled, isFalse);
    expect(after.updatedAt, isNot(before.updatedAt));
    _expectUnrelatedProfileFieldsPreserved(before, after);

    provider.dispose();
  });
}

Future<void> _pumpProfileScreen(
  WidgetTester tester,
  AuthProvider provider,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: provider,
      child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
    ),
  );

  await tester.pump();
  await tester.pump();

  expect(provider.currentProfile, isNotNull);
  expect(find.byType(SwitchListTile), findsOneWidget);
}

ProfileModel _buildProfile({required bool darkModeEnabled}) {
  return ProfileModel(
    uid: 'user-1',
    username: 'traveller',
    displayName: 'Traveller',
    email: 'traveller@example.com',
    photoUrl: 'https://example.com/profile.jpg',
    photoHash: 'photo-hash',
    createdAt: DateTime(2026, 5, 1, 10),
    updatedAt: DateTime(2026, 5, 1, 11),
    darkModeEnabled: darkModeEnabled,
  );
}

void _expectUnrelatedProfileFieldsPreserved(
  ProfileModel before,
  ProfileModel after,
) {
  expect(after.uid, before.uid);
  expect(after.username, before.username);
  expect(after.displayName, before.displayName);
  expect(after.email, before.email);
  expect(after.photoUrl, before.photoUrl);
  expect(after.photoHash, before.photoHash);
  expect(after.createdAt, before.createdAt);
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._profile);

  final ProfileModel _profile;
  final _FakeUser _user = _FakeUser(
    uid: 'user-1',
    email: 'traveller@example.com',
  );

  final List<bool> darkModeUpdates = <bool>[];

  void clearRecordedActions() {
    darkModeUpdates.clear();
  }

  @override
  Stream<firebase_auth.User?> authStateChanges() =>
      Stream<firebase_auth.User?>.value(_user);

  @override
  firebase_auth.User? get currentUser => _user;

  @override
  Future<ProfileModel?> getCurrentUserProfile() async => _profile;

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<void> updateDarkModePreference(bool enabled) async {
    darkModeUpdates.add(enabled);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements firebase_auth.User {
  _FakeUser({required this.uid, required this.email});

  @override
  final String uid;

  @override
  final String? email;

  @override
  bool get emailVerified => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
