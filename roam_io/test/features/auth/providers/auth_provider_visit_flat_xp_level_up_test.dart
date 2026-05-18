/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Verifies AuthProvider.addXp records a pending level-up when flat visit XP
 *   (50) pushes total XP across a level boundary.
 */

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';
import 'package:roam_io/features/profile/domain/xp_reward_config.dart';

void main() {
  test(
    'addXp with visit-sized grant sets pendingLevelUp when crossing boundary',
    () async {
      final threshold = ProfileModel.xpForLevel(1);
      final startXp = threshold - 1;
      expect(ProfileModel.levelFromXp(startXp), 1);

      ProfileModel profile = _baseProfile(xp: startXp, level: 1);
      final repo = _MutableProfileAuthRepository(() => profile, (p) {
        profile = p;
      });

      final auth = AuthProvider(authRepository: repo);
      await auth.refreshCurrentUser();

      expect(auth.pendingLevelUp, isNull);

      await auth.addXp(XpRewardConfig.visitXpReward);

      expect(auth.currentProfile!.xp, startXp + XpRewardConfig.visitXpReward);
      expect(auth.currentProfile!.level, greaterThan(1));
      expect(auth.pendingLevelUp, auth.currentProfile!.level);

      auth.dispose();
    },
  );
}

ProfileModel _baseProfile({required int xp, required int level}) {
  final now = DateTime.utc(2026, 5, 12);
  return ProfileModel(
    uid: 'u1',
    username: 't',
    displayName: 'T',
    email: 't@t.com',
    createdAt: now,
    updatedAt: now,
    xp: xp,
    level: level,
  );
}

class _MutableProfileAuthRepository implements AuthRepository {
  _MutableProfileAuthRepository(this._read, this._write);

  final ProfileModel Function() _read;
  final void Function(ProfileModel) _write;

  final _FakeUser _user = _FakeUser(uid: 'u1', email: 't@t.com');

  @override
  firebase_auth.User? get currentUser => _user;

  @override
  Stream<firebase_auth.User?> authStateChanges() =>
      Stream<firebase_auth.User?>.value(_user);

  @override
  Future<ProfileModel?> getCurrentUserProfile() async => _read();

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<void> addXp(int xpToAdd) async {
    final current = _read();
    final newXp = current.xp + xpToAdd;
    final newLevel = ProfileModel.levelFromXp(newXp);
    _write(
      current.copyWith(
        xp: newXp,
        level: newLevel,
        updatedAt: DateTime.now().toUtc(),
      ),
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
