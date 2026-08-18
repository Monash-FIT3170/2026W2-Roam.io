/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Service tests for creating real persisted test activities with per-user
 *   counters and public profile identity.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/activity_feed/data/activity_creation_service.dart';
import 'package:roam_io/features/activity_feed/data/activity_feed_service.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';

void main() {
  test(
    'creates sequential activity docs from public profile identity',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('public_profiles').doc('user-1').set({
        'uid': 'user-1',
        'username': 'traveller',
        'usernameSearch': 'traveller',
        'displayName': 'Traveller',
        'displayNameSearch': 'traveller',
        'photoUrl': 'https://example.com/avatar.png',
        'createdAt': DateTime(2026, 8, 10).toIso8601String(),
        'updatedAt': DateTime(2026, 8, 10).toIso8601String(),
      });
      final service = ActivityCreationService(firestore: firestore);

      final first = await service.createTestActivityForUser(userId: 'user-1');
      final second = await service.createTestActivityForUser(userId: 'user-1');

      expect(first.title, 'Traveller Activity 1');
      expect(second.title, 'Traveller Activity 2');
      expect(first.id, isNot(second.id));
      expect(first.id, isNot(first.title));

      final docs = await firestore.collection('activities').get();
      expect(docs.docs, hasLength(2));
      final secondDoc = await firestore
          .collection('activities')
          .doc(second.id)
          .get();
      final data = secondDoc.data()!;
      expect(data['activityId'], second.id);
      expect(data['ownerId'], 'user-1');
      expect(data['profileId'], 'user-1');
      expect(data['displayName'], 'Traveller');
      expect(data['username'], 'traveller');
      expect(data['photoUrl'], 'https://example.com/avatar.png');
      expect(data['title'], 'Traveller Activity 2');
      expect(data['kind'], 'exploration');
      expect(data['showMapPreview'], isTrue);
      expect(data['metrics'], isA<List>());
      expect(data.containsKey('kudos'), isFalse);
      expect(data.containsKey('kudosCount'), isFalse);
      expect(data.containsKey('commentCount'), isFalse);

      final counter = await firestore
          .collection('activity_counters')
          .doc('user-1')
          .get();
      expect(counter.data()?['ownerId'], 'user-1');
      expect(counter.data()?['lastTestActivityNumber'], 2);
    },
  );

  test(
    'falls back to the signed-in profile when public profile is missing',
    () async {
      final firestore = FakeFirebaseFirestore();
      final service = ActivityCreationService(firestore: firestore);

      final activity = await service.createTestActivityForUser(
        userId: 'user-1',
        fallbackProfile: ProfileModel(
          uid: 'user-1',
          username: 'fallback_user',
          displayName: 'Fallback User',
          email: 'fallback@example.com',
          createdAt: DateTime(2026, 8, 10),
          updatedAt: DateTime(2026, 8, 10),
        ),
      );

      expect(activity.title, 'Fallback User Activity 1');
      final doc = await firestore
          .collection('activities')
          .doc(activity.id)
          .get();
      expect(doc.data()?['displayName'], 'Fallback User');
      expect(doc.data()?['username'], 'fallback_user');
    },
  );

  test(
    'activity reader skips one malformed document without dropping valid siblings',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('activities').doc('valid-activity').set({
        'activityId': 'valid-activity',
        'ownerId': 'user-1',
        'profileId': 'user-1',
        'displayName': 'Traveller',
        'username': 'traveller',
        'title': 'Traveller Activity 1',
        'kind': 'exploration',
        'showMapPreview': true,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 8, 10)),
        'metrics': [
          {'label': 'XP Gained', 'value': '+120 XP'},
        ],
      });
      await firestore.collection('activities').doc('malformed-activity').set({
        'activityId': 'malformed-activity',
        'ownerId': 'user-1',
        'profileId': 'user-1',
        'displayName': 'Traveller',
        'username': 'traveller',
        'title': 42,
        'kind': 'exploration',
        'showMapPreview': true,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 8, 9)),
        'metrics': [
          {'label': 'XP Gained', 'value': '+10 XP'},
        ],
      });
      final service = ActivityFeedService(firestore: firestore);

      final activities = await service.watchActivitiesOwnedBy('user-1').first;

      expect(activities, hasLength(1));
      expect(activities.single.id, 'valid-activity');
      expect(activities.single.title, 'Traveller Activity 1');
    },
  );
}
