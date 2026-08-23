/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 5 August 2026
 * Description:
 *   Unit tests for AuthProvider account updates, error mapping, and XP level-up
 *   notifications.
 */

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';
import 'package:roam_io/features/profile/domain/xp_award_result.dart';
import 'package:roam_io/features/profile/domain/xp_event.dart';
import 'package:roam_io/theme/app_theme_mode.dart';

import '../../../support/fake_firebase_user.dart';

void main() {
  group('AuthProvider profile updates', () {
    test(
      'updates display name locally without refreshing user/profile',
      () async {
        final now = DateTime(2026, 5, 1);
        final profile = ProfileModel(
          uid: 'u1',
          username: 't',
          displayName: 'Old Name',
          email: 't@t.com',
          createdAt: now,
          updatedAt: now,
        );
        final user = FakeFirebaseUser(uid: 'u1', email: 't@t.com');
        final repo = _XpTrackingRepository(user: user, initialProfile: profile);
        final provider = AuthProvider(authRepository: repo);
        await Future<void>.delayed(Duration.zero);
        await provider.refreshCurrentUser();
        repo.resetCounts();

        await provider.updateDisplayName('New Name');

        expect(repo.updatedDisplayName, 'New Name');
        expect(repo.reloadCount, 0);
        expect(repo.profileReadCount, 0);
        expect(provider.currentProfile?.displayName, 'New Name');
        provider.dispose();
      },
    );

    test('updates username locally without refreshing user/profile', () async {
      final now = DateTime(2026, 5, 1);
      final profile = ProfileModel(
        uid: 'u1',
        username: 'oldname',
        displayName: 'Traveller',
        email: 't@t.com',
        createdAt: now,
        updatedAt: now,
      );
      final user = FakeFirebaseUser(uid: 'u1', email: 't@t.com');
      final repo = _XpTrackingRepository(user: user, initialProfile: profile);
      final provider = AuthProvider(authRepository: repo);
      await Future<void>.delayed(Duration.zero);
      await provider.refreshCurrentUser();
      repo.resetCounts();

      await provider.updateUsername('newname');

      expect(repo.updatedUsername, 'newname');
      expect(repo.reloadCount, 0);
      expect(repo.profileReadCount, 0);
      expect(provider.currentProfile?.username, 'newname');
      provider.dispose();
    });

    test('requests email change through repository', () async {
      final now = DateTime(2026, 5, 1);
      final profile = ProfileModel(
        uid: 'u1',
        username: 'traveller',
        displayName: 'Traveller',
        email: 't@t.com',
        createdAt: now,
        updatedAt: now,
      );
      final user = FakeFirebaseUser(uid: 'u1', email: 't@t.com');
      final repo = _XpTrackingRepository(user: user, initialProfile: profile);
      final provider = AuthProvider(authRepository: repo);
      await Future<void>.delayed(Duration.zero);

      await provider.requestEmailChange(
        currentPassword: 'current-password',
        newEmail: 'new@example.com',
      );

      expect(repo.emailChangePassword, 'current-password');
      expect(repo.emailChangeNewEmail, 'new@example.com');
      provider.dispose();
    });
  });

  group('AuthProvider error messages', () {
    test('maps invalid-email to a friendly message', () async {
      final repo = _ThrowingAuthRepository(
        onSignIn: () => throw firebase_auth.FirebaseAuthException(
          code: 'invalid-email',
          message: 'bad',
        ),
      );
      final provider = AuthProvider(authRepository: repo);
      await provider.signIn(email: 'x', password: 'y');
      expect(provider.errorMessage, 'Please enter a valid email address.');
      provider.dispose();
    });

    test('maps wrong-password to invalid credentials message', () async {
      final repo = _ThrowingAuthRepository(
        onSignIn: () => throw firebase_auth.FirebaseAuthException(
          code: 'wrong-password',
          message: 'bad',
        ),
      );
      final provider = AuthProvider(authRepository: repo);
      await provider.signIn(email: 'a@b.com', password: 'wrong');
      expect(provider.errorMessage, 'Invalid email or password.');
      provider.dispose();
    });

    test('maps permission-denied Firestore errors', () async {
      final repo = _ThrowingAuthRepository(
        onUpdateDarkMode: () => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'denied',
        ),
      );
      final provider = AuthProvider(authRepository: repo);
      await provider.updateDarkModePreference(true);
      expect(
        provider.errorMessage,
        'You do not have permission to perform this action.',
      );
      provider.dispose();
    });
  });

  group('AuthProvider XP', () {
    // Profile is loaded via authStateChanges before addXp is exercised.
    test('sets pendingLevelUp when addXp crosses a level boundary', () async {
      final now = DateTime(2026, 5, 1);
      final profile = ProfileModel(
        uid: 'u1',
        username: 't',
        displayName: 'T',
        email: 't@t.com',
        createdAt: now,
        updatedAt: now,
        xp: 0,
        level: 1,
      );
      final user = FakeFirebaseUser(uid: 'u1', email: 't@t.com');
      final repo = _XpTrackingRepository(user: user, initialProfile: profile);
      final provider = AuthProvider(authRepository: repo);
      await Future<void>.delayed(Duration.zero);
      await provider.refreshCurrentUser();
      repo.resetCounts();

      await provider.addXp(100);
      expect(provider.pendingLevelUp, 2);
      expect(provider.currentProfile?.xp, 100);
      expect(provider.currentProfile?.level, greaterThanOrEqualTo(2));
      expect(repo.addXpCount, 1);
      expect(repo.updateXpCount, 0);
      expect(repo.profileReadCount, 0);

      provider.clearPendingLevelUp();
      expect(provider.pendingLevelUp, isNull);
      provider.dispose();
    });

    test('does not set pendingLevelUp when level is unchanged', () async {
      final now = DateTime(2026, 5, 1);
      final profile = ProfileModel(
        uid: 'u1',
        username: 't',
        displayName: 'T',
        email: 't@t.com',
        createdAt: now,
        updatedAt: now,
        xp: 10,
        level: 1,
      );
      final user = FakeFirebaseUser(uid: 'u1', email: 't@t.com');
      final repo = _XpTrackingRepository(user: user, initialProfile: profile);
      final provider = AuthProvider(authRepository: repo);
      await Future<void>.delayed(Duration.zero);
      await provider.refreshCurrentUser();

      await provider.addXp(5);
      expect(provider.pendingLevelUp, isNull);
      provider.dispose();
    });

    test('can defer and resume level-up celebration overlay', () async {
      final repo = _XpTrackingRepository(
        user: FakeFirebaseUser(uid: 'u1', email: 't@t.com'),
        initialProfile: ProfileModel(
          uid: 'u1',
          username: 't',
          displayName: 'T',
          email: 't@t.com',
          createdAt: DateTime(2026, 5, 1),
          updatedAt: DateTime(2026, 5, 1),
        ),
      );
      final provider = AuthProvider(authRepository: repo);

      expect(provider.deferLevelUpCelebration, isFalse);
      provider.deferLevelUpCelebrationOverlay();
      expect(provider.deferLevelUpCelebration, isTrue);
      provider.resumeLevelUpCelebrationOverlay();
      expect(provider.deferLevelUpCelebration, isFalse);

      provider.dispose();
    });
  });
}

/// Invokes optional callbacks so Firebase and Firestore errors can be injected.
class _ThrowingAuthRepository implements AuthRepository {
  _ThrowingAuthRepository({this.onSignIn, this.onUpdateDarkMode});

  final Future<void> Function()? onSignIn;
  final Future<void> Function()? onUpdateDarkMode;

  @override
  Stream<firebase_auth.User?> authStateChanges() async* {
    yield null;
  }

  @override
  firebase_auth.User? get currentUser => null;

  @override
  Future<void> signIn({required String email, required String password}) async {
    final fn = onSignIn;
    if (fn != null) await fn();
  }

  @override
  Future<void> updateThemeModePreference(AppThemeMode mode) async {
    final fn = onUpdateDarkMode;
    if (fn != null) await fn();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mirrors [addXp] into an in-memory profile for level-up assertions.
class _XpTrackingRepository implements AuthRepository {
  _XpTrackingRepository({
    required this.user,
    required ProfileModel initialProfile,
  }) : _profile = initialProfile;

  final firebase_auth.User user;
  ProfileModel _profile;
  int reloadCount = 0;
  int profileReadCount = 0;
  int addXpCount = 0;
  int updateXpCount = 0;
  String? updatedDisplayName;
  String? updatedUsername;
  String? emailChangePassword;
  String? emailChangeNewEmail;

  @override
  Stream<firebase_auth.User?> authStateChanges() async* {
    yield user;
  }

  @override
  firebase_auth.User? get currentUser => user;

  @override
  Future<void> reloadCurrentUser() async {
    reloadCount++;
  }

  @override
  Future<ProfileModel?> getCurrentUserProfile() async {
    profileReadCount++;
    return _profile;
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
  Future<XpAwardResult> addXp(
    int xpToAdd, {
    XpEventSource source = XpEventSource.unknown,
    String? sourceId,
  }) async {
    addXpCount++;
    final previousXp = _profile.xp;
    final previousLevel = _profile.level;
    final nextXp = previousXp + xpToAdd;
    final nextLevel = ProfileModel.levelFromXp(nextXp);
    _profile = _profile.copyWith(xp: nextXp, level: nextLevel);
    return XpAwardResult.success(
      amount: xpToAdd,
      previousXp: previousXp,
      newXp: nextXp,
      previousLevel: previousLevel,
      newLevel: nextLevel,
      historyRecorded: true,
    );
  }

  @override
  Future<void> updateXp(int newXp) async {
    updateXpCount++;
    final nextLevel = ProfileModel.levelFromXp(newXp);
    _profile = _profile.copyWith(xp: newXp, level: nextLevel);
  }

  void resetCounts() {
    reloadCount = 0;
    profileReadCount = 0;
    addXpCount = 0;
    updateXpCount = 0;
    updatedDisplayName = null;
    updatedUsername = null;
    emailChangePassword = null;
    emailChangeNewEmail = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
