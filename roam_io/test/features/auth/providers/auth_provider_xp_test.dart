/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Tests immediate profile XP and level state updates in the auth provider.
 */

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';

void main() {
  group('AuthProvider XP updates', () {
    test('addXp updates local profile XP and level immediately', () async {
      final repository = _FakeAuthRepository(_profile(xp: 0, level: 1));
      final provider = AuthProvider(authRepository: repository);
      await provider.refreshCurrentUser();

      await provider.addXp(50);

      expect(repository.addedXp, <int>[50]);
      expect(provider.currentProfile?.xp, 50);
      expect(provider.currentProfile?.level, 1);
      expect(provider.pendingLevelUp, isNull);

      provider.dispose();
    });

    test(
      'addXp sets pending level-up when XP crosses a level boundary',
      () async {
        final repository = _FakeAuthRepository(_profile(xp: 90, level: 1));
        final provider = AuthProvider(authRepository: repository);
        await provider.refreshCurrentUser();

        await provider.addXp(20);

        expect(provider.currentProfile?.xp, 110);
        expect(provider.currentProfile?.level, 2);
        expect(provider.pendingLevelUp, 2);

        provider.dispose();
      },
    );

    test('updateXp updates local profile XP and level immediately', () async {
      final repository = _FakeAuthRepository(_profile(xp: 0, level: 1));
      final provider = AuthProvider(authRepository: repository);
      await provider.refreshCurrentUser();

      await provider.updateXp(212);

      expect(repository.updatedXp, <int>[212]);
      expect(provider.currentProfile?.xp, 212);
      expect(provider.currentProfile?.level, 2);
      expect(provider.pendingLevelUp, 2);

      provider.dispose();
    });
  });
}

ProfileModel _profile({required int xp, required int level}) {
  return ProfileModel(
    uid: 'user-1',
    username: 'traveller',
    displayName: 'Traveller',
    email: 'traveller@example.com',
    createdAt: DateTime(2026, 5, 1),
    updatedAt: DateTime(2026, 5, 1),
    xp: xp,
    level: level,
  );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._profile);

  ProfileModel _profile;
  final _FakeUser _user = _FakeUser(
    uid: 'user-1',
    email: 'traveller@example.com',
  );
  final List<int> addedXp = <int>[];
  final List<int> updatedXp = <int>[];

  @override
  Stream<firebase_auth.User?> authStateChanges() {
    return Stream<firebase_auth.User?>.value(_user);
  }

  @override
  firebase_auth.User? get currentUser => _user;

  @override
  Future<ProfileModel?> getCurrentUserProfile() async => _profile;

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<void> addXp(int xpToAdd) async {
    addedXp.add(xpToAdd);
    final nextXp = _profile.xp + xpToAdd;
    _profile = _profile.copyWith(
      xp: nextXp,
      level: ProfileModel.levelFromXp(nextXp),
    );
  }

  @override
  Future<void> updateXp(int newXp) async {
    updatedXp.add(newXp);
    _profile = _profile.copyWith(
      xp: newXp,
      level: ProfileModel.levelFromXp(newXp),
    );
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
