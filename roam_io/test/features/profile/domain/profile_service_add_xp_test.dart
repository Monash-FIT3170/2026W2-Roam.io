/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Regression tests for ProfileService.addXp: canonical progression must
 *   succeed even when secondary xp_events history recording fails.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';
import 'package:roam_io/features/profile/domain/xp_event.dart';
import 'package:roam_io/features/social/data/friendship_service.dart';
import 'package:roam_io/services/profile_service.dart';

void main() {
  group('ProfileService.addXp', () {
    test('createProfile writes the public search profile mirror', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ProfileService(firestore: firestore);

      await service.createProfile(
        _profile(
          uid: 'u1',
          xp: 0,
          level: 1,
        ).copyWith(username: 'TravellerOne', displayName: 'Traveller One'),
      );

      final publicProfile = await firestore
          .collection('public_profiles')
          .doc('u1')
          .get();

      expect(publicProfile.exists, isTrue);
      expect(publicProfile.data()?['username'], 'TravellerOne');
      expect(publicProfile.data()?['usernameSearch'], 'travellerone');
      expect(publicProfile.data()?['displayName'], 'Traveller One');
      expect(publicProfile.data()?['displayNameSearch'], 'traveller one');
      expect(publicProfile.data()?['xp'], 0);
      expect(publicProfile.data()?['level'], 1);
      expect(publicProfile.data()?.containsKey('email'), isFalse);
    });

    test(
      'public profile projection failure does not fail profile creation',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = ProfileService(
          firestore: firestore,
          friendshipService: _ThrowingProjectionFriendshipService(),
        );

        await service.createProfile(_profile(uid: 'u1', xp: 0, level: 1));

        final privateProfile = await firestore
            .collection('profiles')
            .doc('u1')
            .get();
        expect(privateProfile.exists, isTrue);
      },
    );

    test(
      'awards canonical XP and records history when history write succeeds',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = ProfileService(firestore: firestore);
        await service.createProfile(_profile(uid: 'u1', xp: 40, level: 1));

        final result = await service.addXp(
          'u1',
          50,
          source: XpEventSource.tileUnlock,
          sourceId: 'region-1',
        );

        expect(result.succeeded, isTrue);
        expect(result.amount, 50);
        expect(result.previousXp, 40);
        expect(result.newXp, 90);
        expect(result.previousLevel, 1);
        expect(result.newLevel, 1);
        expect(result.didLevelUp, isFalse);
        expect(result.historyRecorded, isTrue);

        final profile = await service.getProfile('u1');
        expect(profile?.xp, 90);
        expect(profile?.level, 1);

        final events = await firestore
            .collection('profiles')
            .doc('u1')
            .collection('xp_events')
            .get();
        expect(events.docs, hasLength(1));
        expect(events.docs.first.data()['amount'], 50);
        expect(events.docs.first.data()['source'], 'tileUnlock');
        expect(events.docs.first.data()['sourceId'], 'region-1');
      },
    );

    test(
      'keeps canonical XP when xp_events write fails (ART2-86 regression)',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = ProfileService(
          firestore: firestore,
          recordXpEvent: (uid, event) async {
            throw Exception('simulated xp_events permission-denied');
          },
        );
        await service.createProfile(_profile(uid: 'u1', xp: 90, level: 1));

        final result = await service.addXp(
          'u1',
          20,
          source: XpEventSource.visit,
        );

        expect(result.succeeded, isTrue);
        expect(result.historyRecorded, isFalse);
        expect(result.previousXp, 90);
        expect(result.newXp, 110);
        expect(result.didLevelUp, isTrue);
        expect(result.newLevel, 2);

        final profile = await service.getProfile('u1');
        expect(profile?.xp, 110);
        expect(profile?.level, 2);

        final events = await firestore
            .collection('profiles')
            .doc('u1')
            .collection('xp_events')
            .get();
        expect(events.docs, isEmpty);
      },
    );

    test('returns failed when profile document is missing', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ProfileService(firestore: firestore);

      final result = await service.addXp('missing', 50);

      expect(result.succeeded, isFalse);
      expect(result.historyRecorded, isFalse);
      expect(result.amount, 50);
    });

    test('returns failed for non-positive XP amounts', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ProfileService(firestore: firestore);
      await service.createProfile(_profile(uid: 'u1', xp: 10, level: 1));

      final result = await service.addXp('u1', 0);

      expect(result.succeeded, isFalse);
      final profile = await service.getProfile('u1');
      expect(profile?.xp, 10);
    });

    test('crosses a level threshold and persists derived level', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ProfileService(firestore: firestore);
      await service.createProfile(_profile(uid: 'u1', xp: 90, level: 1));

      final result = await service.addXp('u1', 50);

      expect(result.succeeded, isTrue);
      expect(result.newXp, 140);
      expect(result.newLevel, ProfileModel.levelFromXp(140));
      expect(result.didLevelUp, isTrue);

      final profile = await service.getProfile('u1');
      expect(profile?.level, result.newLevel);
    });

    test(
      'public profile projection failure does not fail XP progression',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = ProfileService(
          firestore: firestore,
          friendshipService: _ThrowingProjectionFriendshipService(),
        );
        await firestore
            .collection('profiles')
            .doc('u1')
            .set(_profile(uid: 'u1', xp: 90, level: 1).toMap());

        final result = await service.addXp('u1', 50);

        expect(result.succeeded, isTrue);
        expect(result.newXp, 140);
        final profile = await service.getProfile('u1');
        expect(profile?.xp, 140);
        expect(profile?.level, ProfileModel.levelFromXp(140));
      },
    );
  });
}

class _ThrowingProjectionFriendshipService implements FriendshipService {
  @override
  Future<void> upsertPublicProfile({
    required String uid,
    required String username,
    required String displayName,
    String? photoUrl,
    DateTime? createdAt,
    int? xp,
    int? level,
  }) async {
    throw Exception('simulated public projection failure');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProfileModel _profile({
  required String uid,
  required int xp,
  required int level,
}) {
  final now = DateTime(2026, 8, 6);
  return ProfileModel(
    uid: uid,
    username: 'traveller',
    displayName: 'Traveller',
    email: 'traveller@example.com',
    createdAt: now,
    updatedAt: now,
    xp: xp,
    level: level,
  );
}
