import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';

import '../../../support/fake_firebase_user.dart';

void main() {
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

      await provider.addXp(100);
      expect(provider.pendingLevelUp, 2);
      expect(provider.currentProfile?.xp, 100);
      expect(provider.currentProfile?.level, greaterThanOrEqualTo(2));

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

      await provider.addXp(5);
      expect(provider.pendingLevelUp, isNull);
      provider.dispose();
    });
  });
}

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
  Future<void> updateDarkModePreference(bool enabled) async {
    final fn = onUpdateDarkMode;
    if (fn != null) await fn();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _XpTrackingRepository implements AuthRepository {
  _XpTrackingRepository({
    required this.user,
    required ProfileModel initialProfile,
  }) : _profile = initialProfile;

  final firebase_auth.User user;
  ProfileModel _profile;

  @override
  Stream<firebase_auth.User?> authStateChanges() async* {
    yield user;
  }

  @override
  firebase_auth.User? get currentUser => user;

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<ProfileModel?> getCurrentUserProfile() async => _profile;

  @override
  Future<void> addXp(int xpToAdd) async {
    final nextXp = _profile.xp + xpToAdd;
    final nextLevel = ProfileModel.levelFromXp(nextXp);
    _profile = _profile.copyWith(xp: nextXp, level: nextLevel);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
