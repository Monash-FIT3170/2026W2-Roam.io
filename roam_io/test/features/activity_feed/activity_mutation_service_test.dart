/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 22 October 2026
 * Description:
 *   Unit tests for ActivityMutationService deletion, including cascading
 *   removal of Kudos, comments, comment likes, and attached media.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/activity_feed/data/activity_mutation_service.dart';
import 'package:roam_io/features/activity_feed/models/activity_feed_item.dart';
import 'package:roam_io/services/storage_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late List<String> deletedStoragePaths;
  late ActivityMutationService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    deletedStoragePaths = <String>[];
    service = ActivityMutationService(
      firestore: firestore,
      storageService: StorageService(
        activityMediaDeleteOverride: ({required String storagePath}) async {
          deletedStoragePaths.add(storagePath);
        },
      ),
    );
  });

  ActivityFeedItem createTestActivity({
    required String id,
    required String ownerId,
    List<ActivityMediaItem> media = const [],
    String? mapImageStoragePath,
  }) {
    return ActivityFeedItem(
      id: id,
      ownerId: ownerId,
      displayName: 'Owner',
      timestampLabel: 'Just now',
      username: 'owner',
      title: 'Morning Walk',
      kind: ActivityFeedKind.journey,
      sourceJourneyId: 'journey-1',
      metrics: const [],
      createdAt: DateTime.now(),
      media: media,
      mapImageStoragePath: mapImageStoragePath,
    );
  }

  test(
    'deleteActivity deletes activity document when there are no subcollections',
    () async {
      final activity = createTestActivity(id: 'activity-1', ownerId: 'owner-1');
      await firestore.collection('activities').doc(activity.id).set({
        'activityId': activity.id,
        'ownerId': activity.ownerId,
        'title': activity.title,
      });

      await service.deleteActivity(activity);

      final doc = await firestore
          .collection('activities')
          .doc(activity.id)
          .get();
      expect(doc.exists, isFalse);
    },
  );

  test(
    'deleteActivity deletes activity, kudos, comments, and comment likes subcollections',
    () async {
      final activity = createTestActivity(
        id: 'journey_123',
        ownerId: 'owner-1',
        media: [
          ActivityMediaItem(
            id: 'media-1',
            type: ActivityMediaType.photo,
            url: 'https://example.com/photo.jpg',
            storagePath: 'activity_media/owner-1/journey_123/media-1.jpg',
            order: 0,
            createdAt: DateTime.now(),
          ),
        ],
        mapImageStoragePath: 'activity_media/owner-1/journey_123/map.png',
      );

      final activityRef = firestore.collection('activities').doc(activity.id);
      await activityRef.set({
        'activityId': activity.id,
        'ownerId': activity.ownerId,
        'title': activity.title,
      });

      // Seed kudos from a glazer
      await activityRef.collection('kudos').doc('glazer-1').set({
        'activityId': activity.id,
        'activityOwnerId': activity.ownerId,
        'userId': 'glazer-1',
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Seed a comment and a like on that comment
      final commentRef = activityRef.collection('comments').doc('comment-1');
      await commentRef.set({
        'activityId': activity.id,
        'authorId': 'commenter-1',
        'text': 'Great journey!',
        'createdAt': DateTime.now().toIso8601String(),
      });
      await commentRef.collection('likes').doc('liker-1').set({
        'activityId': activity.id,
        'commentId': 'comment-1',
        'commentAuthorId': 'commenter-1',
        'userId': 'liker-1',
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Seed a reply comment
      final replyRef = activityRef.collection('comments').doc('reply-1');
      await replyRef.set({
        'activityId': activity.id,
        'authorId': 'owner-1',
        'parentCommentId': 'comment-1',
        'text': 'Thanks!',
        'createdAt': DateTime.now().toIso8601String(),
      });

      await service.deleteActivity(activity);

      // Verify activity document is deleted
      final activityDoc = await activityRef.get();
      expect(activityDoc.exists, isFalse);

      // Verify kudos are deleted
      final kudosSnapshot = await activityRef.collection('kudos').get();
      expect(kudosSnapshot.docs, isEmpty);

      // Verify comments and comment likes are deleted
      final commentsSnapshot = await activityRef.collection('comments').get();
      expect(commentsSnapshot.docs, isEmpty);
      final likesSnapshot = await commentRef.collection('likes').get();
      expect(likesSnapshot.docs, isEmpty);

      // Verify media was cleaned up
      expect(
        deletedStoragePaths,
        containsAll([
          'activity_media/owner-1/journey_123/media-1.jpg',
          'activity_media/owner-1/journey_123/map.png',
        ]),
      );
    },
  );
}
