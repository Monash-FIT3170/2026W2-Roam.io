/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Unit tests for SocialNotificationService unread/read persistence.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/social/data/follow_service.dart';
import 'package:roam_io/features/social/data/social_notification_service.dart';
import 'package:roam_io/features/social/domain/social_notification.dart';

void main() {
  test('watchRecent returns newest first and unread count updates', () async {
    final firestore = FakeFirebaseFirestore();
    final service = SocialNotificationService(firestore: firestore);

    await service.upsertFollowNotificationForTests(
      recipientId: 'user-b',
      actorId: 'user-a',
      notificationId: SocialNotification.followNotificationIdFor(
        followerId: 'user-a',
        followeeId: 'user-b',
      ),
      createdAt: DateTime(2026, 8, 7, 10),
    );
    await service.upsertFollowNotificationForTests(
      recipientId: 'user-b',
      actorId: 'user-c',
      notificationId: SocialNotification.followNotificationIdFor(
        followerId: 'user-c',
        followeeId: 'user-b',
      ),
      createdAt: DateTime(2026, 8, 7, 12),
    );

    final recent = await service.watchRecent('user-b').first;
    expect(recent.length, 2);
    expect(recent.first.actorId, 'user-c');
    expect(await service.watchUnreadCount('user-b').first, 2);

    await service.markAllRead('user-b');
    expect(await service.watchUnreadCount('user-b').first, 0);
    final afterRead = await service.watchRecent('user-b').first;
    expect(afterRead.every((item) => item.isRead), isTrue);
  });

  test(
    'follow back and removeFollower update counts without notify on remove',
    () async {
      final firestore = FakeFirebaseFirestore();
      final followService = FollowService(firestore: firestore);
      final notificationService = SocialNotificationService(
        firestore: firestore,
      );

      await followService.follow(followerId: 'user-a', followeeId: 'user-b');
      // Client dual-write (and/or CF) creates B's inbox row.
      expect((await notificationService.watchRecent('user-b').first).length, 1);

      // Follow Back: B follows A → notifies A; does not clear B's row.
      await followService.follow(followerId: 'user-b', followeeId: 'user-a');
      expect(await followService.watchFollowingCount('user-b').first, 1);
      expect(await followService.watchFollowerCount('user-a').first, 1);
      expect((await notificationService.watchRecent('user-a').first).length, 1);

      final aCountBeforeRemove =
          (await notificationService.watchRecent('user-a').first).length;
      await followService.removeFollower(
        followerId: 'user-a',
        followeeId: 'user-b',
      );
      expect(await followService.watchFollowerCount('user-b').first, 0);
      expect(await followService.watchFollowingCount('user-a').first, 0);
      // Remove does not fabricate a notification for the removed follower.
      expect(
        (await notificationService.watchRecent('user-a').first).length,
        aCountBeforeRemove,
      );
      expect(await notificationService.watchRecent('user-b').first, isEmpty);
    },
  );

  test('valid persisted activity types preserve exact enum values', () async {
    final notification = SocialNotification.fromMap('kudos-1', {
      'recipientId': 'owner',
      'actorId': 'actor',
      'type': 'activityKudos',
      'createdAt': DateTime(2026, 8, 10).toIso8601String(),
      'activityId': 'activity-1',
    });

    expect(notification.type, SocialNotificationType.activityKudos);
    expect(notification.activityId, 'activity-1');
  });

  test(
    'unknown persisted type is skipped instead of becoming follow',
    () async {
      final firestore = FakeFirebaseFirestore();
      final service = SocialNotificationService(firestore: firestore);
      final notifications = firestore
          .collection('profiles')
          .doc('owner')
          .collection('notifications');

      await notifications.doc('bad').set({
        'recipientId': 'owner',
        'actorId': 'actor',
        'type': 'legacyActivity',
        'createdAt': DateTime(2026, 8, 10, 10).toIso8601String(),
      });
      await notifications.doc('good').set({
        'recipientId': 'owner',
        'actorId': 'actor',
        'type': 'commentLike',
        'createdAt': DateTime(2026, 8, 10, 11).toIso8601String(),
        'activityId': 'activity-1',
        'commentId': 'comment-1',
      });

      final recent = await service.watchRecent('owner').first;

      expect(recent, hasLength(1));
      expect(recent.single.id, 'good');
      expect(recent.single.type, SocialNotificationType.commentLike);
    },
  );
}
