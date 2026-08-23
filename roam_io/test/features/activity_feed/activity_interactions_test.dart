/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 22 August 2026
 * Description:
 *   Service tests for activity-specific Kudos, comments/replies, comment
 *   likes, and persistent social notification rows.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/activity_feed/data/comment_like_service.dart';
import 'package:roam_io/features/activity_feed/data/comment_service.dart';
import 'package:roam_io/features/activity_feed/data/kudos_service.dart';
import 'package:roam_io/features/social/domain/social_notification.dart';

void main() {
  test(
    'Glaze toggles per user/activity and writes one active notification',
    () async {
      final firestore = FakeFirebaseFirestore();
      await _seedActivity(
        firestore,
        activityId: 'activity-1',
        ownerId: 'owner',
      );
      final kudos = KudosService(firestore: firestore);

      await kudos.toggleKudos(
        activityId: 'activity-1',
        activityOwnerId: 'owner',
        userId: 'actor',
      );

      expect(await kudos.watchKudosCount('activity-1').first, 1);
      expect(
        await kudos
            .watchHasGivenKudos(activityId: 'activity-1', userId: 'actor')
            .first,
        isTrue,
      );
      final notificationId = SocialNotification.activityKudosNotificationIdFor(
        activityId: 'activity-1',
        actorId: 'actor',
      );
      final firstNotification = await firestore
          .collection('profiles')
          .doc('owner')
          .collection('notifications')
          .doc(notificationId)
          .get();
      expect(firstNotification.exists, isTrue);
      expect(firstNotification.data()?['type'], 'activityKudos');

      await kudos.toggleKudos(
        activityId: 'activity-1',
        activityOwnerId: 'owner',
        userId: 'actor',
      );

      expect(await kudos.watchKudosCount('activity-1').first, 0);

      await kudos.toggleKudos(
        activityId: 'activity-1',
        activityOwnerId: 'owner',
        userId: 'actor',
      );

      expect(await kudos.watchKudosCount('activity-1').first, 1);
      expect(
        await KudosService(
          firestore: firestore,
        ).watchKudosCount('activity-1').first,
        1,
      );
      final secondNotification = await firestore
          .collection('profiles')
          .doc('owner')
          .collection('notifications')
          .doc(notificationId)
          .get();
      expect(secondNotification.exists, isTrue);
      expect(secondNotification.data()?['actorId'], 'actor');

      await kudos.toggleKudos(
        activityId: 'activity-1',
        activityOwnerId: 'owner',
        userId: 'actor-2',
      );
      await kudos.toggleKudos(
        activityId: 'activity-1',
        activityOwnerId: 'owner',
        userId: 'actor-3',
      );
      expect(await kudos.watchKudosCount('activity-1').first, 3);
      expect(
        await firestore
            .collection('activities')
            .doc('activity-1')
            .collection('kudos')
            .doc('actor')
            .get()
            .then((doc) => doc.exists),
        isTrue,
      );
    },
  );

  test('owners cannot Glaze their own activity', () async {
    final firestore = FakeFirebaseFirestore();
    await _seedActivity(firestore, activityId: 'activity-1', ownerId: 'owner');
    final kudos = KudosService(firestore: firestore);

    await expectLater(
      kudos.toggleKudos(
        activityId: 'activity-1',
        activityOwnerId: 'owner',
        userId: 'owner',
      ),
      throwsA(
        isA<FirebaseException>().having(
          (error) => error.code,
          'code',
          'permission-denied',
        ),
      ),
    );
    expect(await kudos.watchKudosCount('activity-1').first, 0);
  });

  test('watchGlazers deduplicates real profile rows', () async {
    final firestore = FakeFirebaseFirestore();
    await _seedActivity(firestore, activityId: 'activity-1', ownerId: 'owner');
    await firestore.collection('public_profiles').doc('actor').set({
      'displayName': 'Alex Traveller',
      'username': 'alex',
      'photoUrl': 'https://example.com/alex.jpg',
    });
    await firestore.collection('public_profiles').doc('actor-2').set({
      'displayName': '',
      'username': 'sam',
    });
    await firestore
        .collection('activities')
        .doc('activity-1')
        .collection('kudos')
        .doc('actor')
        .set({'userId': 'actor'});
    await firestore
        .collection('activities')
        .doc('activity-1')
        .collection('kudos')
        .doc('actor-duplicate')
        .set({'userId': 'actor'});
    await firestore
        .collection('activities')
        .doc('activity-1')
        .collection('kudos')
        .doc('actor-2')
        .set({'userId': 'actor-2'});

    final glazers = await KudosService(
      firestore: firestore,
    ).watchGlazers('activity-1').first;

    expect(glazers.map((glazer) => glazer.userId), ['actor', 'actor-2']);
    expect(glazers.first.displayName, 'Alex Traveller');
    expect(glazers.first.username, 'alex');
    expect(glazers.first.photoUrl, 'https://example.com/alex.jpg');
    expect(glazers.last.displayName, 'Roam.io user');
  });

  test(
    'comments and replies notify the correct recipients without self rows',
    () async {
      final firestore = FakeFirebaseFirestore();
      await _seedActivity(
        firestore,
        activityId: 'activity-1',
        ownerId: 'owner',
      );
      final comments = CommentService(firestore: firestore);

      final comment = await comments.addComment(
        activityId: 'activity-1',
        activityOwnerId: 'owner',
        authorId: 'commenter',
        authorDisplayName: 'Commenter',
        text: 'Great run',
      );

      expect(await comments.watchCommentCount('activity-1').first, 1);
      expect(
        await CommentService(
          firestore: firestore,
        ).watchCommentCount('activity-1').first,
        1,
      );
      expect(
        await CommentService(firestore: firestore)
            .watchComments('activity-1')
            .first
            .then((comments) => comments.map((comment) => comment.text)),
        contains('Great run'),
      );
      expect(
        await _notificationTypes(firestore, 'owner'),
        contains('activityComment'),
      );

      final reply = await comments.replyToComment(
        activityId: 'activity-1',
        activityOwnerId: 'owner',
        parentComment: comment,
        authorId: 'reply-author',
        authorDisplayName: 'Reply Author',
        text: 'Thanks!',
      );

      expect(reply.parentCommentId, comment.id);
      expect(await comments.watchCommentCount('activity-1').first, 2);
      expect(
        await _notificationTypes(firestore, 'commenter'),
        contains('commentReply'),
      );
      expect(
        await _notificationTypes(firestore, 'owner'),
        containsAll(<String>['activityComment']),
      );

      final ownerComment = await comments.addComment(
        activityId: 'activity-1',
        activityOwnerId: 'owner',
        authorId: 'owner',
        authorDisplayName: 'Owner',
        text: 'Owner comment',
      );
      await comments.replyToComment(
        activityId: 'activity-1',
        activityOwnerId: 'owner',
        parentComment: ownerComment,
        authorId: 'reply-author',
        authorDisplayName: 'Reply Author',
        text: 'Reply to owner',
      );

      final ownerTypes = await _notificationTypes(firestore, 'owner');
      expect(ownerTypes.where((type) => type == 'commentReply'), hasLength(1));
    },
  );

  test(
    'Sanjevan test activity uses real kudos and comments subcollections',
    () async {
      final firestore = FakeFirebaseFirestore();
      await _seedActivity(
        firestore,
        activityId: 'sanjevan-test-activity',
        ownerId: 'sanjevan-uid',
      );
      final kudos = KudosService(firestore: firestore);
      final comments = CommentService(firestore: firestore);

      await kudos.toggleKudos(
        activityId: 'sanjevan-test-activity',
        activityOwnerId: 'sanjevan-uid',
        userId: 'amar-uid',
      );
      await comments.addComment(
        activityId: 'sanjevan-test-activity',
        activityOwnerId: 'sanjevan-uid',
        authorId: 'amar-uid',
        authorDisplayName: 'Amar',
        text: 'Persisted comment',
      );

      final kudosDoc = await firestore
          .collection('activities')
          .doc('sanjevan-test-activity')
          .collection('kudos')
          .doc('amar-uid')
          .get();
      final commentSnapshot = await firestore
          .collection('activities')
          .doc('sanjevan-test-activity')
          .collection('comments')
          .get();

      expect(kudosDoc.exists, isTrue);
      expect(await kudos.watchKudosCount('sanjevan-test-activity').first, 1);
      expect(commentSnapshot.docs, hasLength(1));
      expect(
        await comments.watchCommentCount('sanjevan-test-activity').first,
        1,
      );
      expect(
        await CommentService(firestore: firestore)
            .watchComments('sanjevan-test-activity')
            .first
            .then((comments) => comments.single.text),
        'Persisted comment',
      );
    },
  );

  test(
    'services use the persisted activity owner, not widget fallback owner',
    () async {
      final firestore = FakeFirebaseFirestore();
      await _seedActivity(
        firestore,
        activityId: 'activity-2',
        ownerId: 'real-owner',
      );
      final kudos = KudosService(firestore: firestore);
      final comments = CommentService(firestore: firestore);

      await kudos.toggleKudos(
        activityId: 'activity-2',
        activityOwnerId: 'wrong-owner',
        userId: 'viewer-uid',
      );
      await comments.addComment(
        activityId: 'activity-2',
        activityOwnerId: 'wrong-owner',
        authorId: 'viewer-uid',
        authorDisplayName: 'Viewer',
        text: 'Real path comment',
      );

      final kudosDoc = await firestore
          .collection('activities')
          .doc('activity-2')
          .collection('kudos')
          .doc('viewer-uid')
          .get();
      expect(kudosDoc.exists, isTrue);
      expect(kudosDoc.data()?['activityOwnerId'], 'real-owner');
      expect(await kudos.watchKudosCount('activity-2').first, 1);

      final loaded = await comments.watchComments('activity-2').first;
      expect(loaded.single.text, 'Real path comment');
      expect(
        await _notificationTypes(firestore, 'real-owner'),
        containsAll(<String>['activityKudos', 'activityComment']),
      );
      expect(await _notificationTypes(firestore, 'wrong-owner'), isEmpty);
    },
  );

  test(
    'missing parent activity fails without creating placeholder data',
    () async {
      final firestore = FakeFirebaseFirestore();
      final kudos = KudosService(firestore: firestore);
      final comments = CommentService(firestore: firestore);

      await expectLater(
        kudos.toggleKudos(
          activityId: 'missing-activity',
          activityOwnerId: 'actor',
          userId: 'actor',
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        comments.addComment(
          activityId: 'missing-activity',
          activityOwnerId: 'actor',
          authorId: 'actor',
          authorDisplayName: 'Actor',
          text: 'Should fail',
        ),
        throwsA(isA<Exception>()),
      );

      final parent = await firestore
          .collection('activities')
          .doc('missing-activity')
          .get();
      expect(parent.exists, isFalse);
    },
  );

  test(
    'comment likes toggle per user/comment and notify comment author',
    () async {
      final firestore = FakeFirebaseFirestore();
      await _seedActivity(
        firestore,
        activityId: 'activity-1',
        ownerId: 'owner',
      );
      final comments = CommentService(firestore: firestore);
      final likes = CommentLikeService(firestore: firestore);
      final comment = await comments.addComment(
        activityId: 'activity-1',
        activityOwnerId: 'owner',
        authorId: 'commenter',
        authorDisplayName: 'Commenter',
        text: 'Great run',
      );

      await likes.toggleLike(
        activityId: 'activity-1',
        commentId: comment.id,
        commentAuthorId: 'commenter',
        userId: 'actor',
      );

      expect(
        await likes
            .watchLikeCount(activityId: 'activity-1', commentId: comment.id)
            .first,
        1,
      );
      expect(
        await likes
            .watchIsLiked(
              activityId: 'activity-1',
              commentId: comment.id,
              userId: 'actor',
            )
            .first,
        isTrue,
      );
      expect(
        await _notificationTypes(firestore, 'commenter'),
        contains('commentLike'),
      );

      await likes.toggleLike(
        activityId: 'activity-1',
        commentId: comment.id,
        commentAuthorId: 'commenter',
        userId: 'actor',
      );

      expect(
        await likes
            .watchLikeCount(activityId: 'activity-1', commentId: comment.id)
            .first,
        0,
      );
    },
  );
}

Future<void> _seedActivity(
  FakeFirebaseFirestore firestore, {
  required String activityId,
  required String ownerId,
}) {
  return firestore.collection('activities').doc(activityId).set({
    'ownerId': ownerId,
    'profileId': ownerId,
    'createdAt': DateTime(2026, 8, 10).toIso8601String(),
  });
}

Future<List<String>> _notificationTypes(
  FakeFirebaseFirestore firestore,
  String recipientId,
) async {
  final snapshot = await firestore
      .collection('profiles')
      .doc(recipientId)
      .collection('notifications')
      .get();
  return snapshot.docs
      .map((doc) => doc.data()['type'] as String? ?? '')
      .where((type) => type.isNotEmpty)
      .toList();
}
