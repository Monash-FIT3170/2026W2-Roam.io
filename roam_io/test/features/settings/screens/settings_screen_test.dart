/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Regression tests for row-based Settings appearance/privacy controls and
 *   profile data preservation across Light, Dark, and Dynamic modes.
 */

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';
import 'package:roam_io/features/settings/screens/settings_screen.dart';
import 'package:roam_io/features/settings/widgets/settings_group.dart';
import 'package:roam_io/theme/app_theme_mode.dart';

void main() {
  for (final testCase in <({AppThemeMode from, AppThemeMode to})>[
    (from: AppThemeMode.light, to: AppThemeMode.dark),
    (from: AppThemeMode.dark, to: AppThemeMode.light),
    (from: AppThemeMode.light, to: AppThemeMode.dynamic),
  ]) {
    testWidgets(
      'selecting ${testCase.to.name} preserves existing settings data',
      (tester) async {
        final profile = _buildProfile(themeMode: testCase.from);
        final repository = _FakeAuthRepository(profile);
        final provider = AuthProvider(authRepository: repository);

        await _pumpSettingsScreen(tester, provider);
        repository.clearRecordedActions();

        final before = provider.currentProfile!;
        final appearanceRow = find.text('Appearance');
        await tester.ensureVisible(appearanceRow);
        await tester.tap(appearanceRow);
        await tester.pumpAndSettle();

        expect(find.text('Light'), findsWidgets);
        expect(find.text('Dark'), findsWidgets);
        expect(find.text('Dynamic'), findsWidgets);

        await tester.tap(
          find.byKey(
            ValueKey<String>('theme-mode-${testCase.to.storageValue}'),
          ),
        );
        await tester.pumpAndSettle();

        final after = provider.currentProfile!;
        expect(repository.themeModeUpdates, <AppThemeMode>[testCase.to]);
        expect(after.themeMode, testCase.to);
        expect(after.updatedAt, isNot(before.updatedAt));
        _expectUnrelatedProfileFieldsPreserved(before, after);

        provider.dispose();
      },
    );
  }

  testWidgets('selecting the current mode does not write the profile again', (
    tester,
  ) async {
    final repository = _FakeAuthRepository(
      _buildProfile(themeMode: AppThemeMode.dynamic),
    );
    final provider = AuthProvider(authRepository: repository);

    await _pumpSettingsScreen(tester, provider);
    repository.clearRecordedActions();

    final appearanceRow = find.text('Appearance');
    await tester.ensureVisible(appearanceRow);
    await tester.tap(appearanceRow);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('theme-mode-dynamic')));
    await tester.pumpAndSettle();

    expect(repository.themeModeUpdates, isEmpty);
    provider.dispose();
  });
}

Future<void> _pumpSettingsScreen(
  WidgetTester tester,
  AuthProvider provider,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: provider,
      child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
    ),
  );

  await tester.pump();
  await tester.pump();

  expect(provider.currentProfile, isNotNull);
  expect(find.text('Appearance'), findsOneWidget);
  expect(_switchForRow('Private Account'), findsOneWidget);
}

Finder _switchForRow(String rowTitle) {
  return find.descendant(
    of: find.ancestor(
      of: find.text(rowTitle),
      matching: find.byType(SettingsRow),
    ),
    matching: find.byType(Switch),
  );
}

ProfileModel _buildProfile({required AppThemeMode themeMode}) {
  return ProfileModel(
    uid: 'user-1',
    username: 'traveller',
    displayName: 'Traveller',
    email: 'traveller@example.com',
    photoUrl: 'https://example.com/profile.jpg',
    photoHash: 'photo-hash',
    createdAt: DateTime(2026, 5, 1, 10),
    updatedAt: DateTime(2026, 5, 1, 11),
    themeMode: themeMode,
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

  final List<AppThemeMode> themeModeUpdates = <AppThemeMode>[];

  void clearRecordedActions() {
    themeModeUpdates.clear();
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
  Future<void> updateThemeModePreference(AppThemeMode mode) async {
    themeModeUpdates.add(mode);
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
