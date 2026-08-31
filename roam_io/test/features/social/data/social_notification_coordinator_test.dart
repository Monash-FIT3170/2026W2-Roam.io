/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Unit tests for SocialNotificationCoordinator cold-start summary, live
 *   banner dedupe, and auth UID switching (account change on one device).
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/social/data/friendship_service.dart';
import 'package:roam_io/features/social/data/social_notification_coordinator.dart';
import 'package:roam_io/features/social/data/social_notification_service.dart';
import 'package:roam_io/features/social/domain/public_profile.dart';
import 'package:roam_io/features/social/domain/social_notification.dart';
import 'package:roam_io/notifications/models/app_notification.dart';
import 'package:roam_io/notifications/models/notification_type.dart';
import 'package:roam_io/notifications/services/notification_service.dart';

void main() {
  late List<AppNotification> shown;

  setUp(() {
    shown = <AppNotification>[];
  });

  NotificationService bannerService() {
    return _CapturingBannerService(shown);
  }

  test('cold start with three unread shows one summary banner', () async {
    final firestore = FakeFirebaseFirestore();
    final friendship = FriendshipService(firestore: firestore);
    final notif = SocialNotificationService(firestore: firestore);
    await friendship.upsertPublicProfile(
      uid: 'a',
      username: 'a',
      displayName: 'Alice',
    );
    await friendship.upsertPublicProfile(
      uid: 'c',
      username: 'c',
      displayName: 'Cara',
    );
    await friendship.upsertPublicProfile(
      uid: 'd',
      username: 'd',
      displayName: 'Dan',
    );

    for (final actor in ['a', 'c', 'd']) {
      await notif.upsertFollowNotificationForTests(
        recipientId: 'b',
        actorId: actor,
        notificationId: SocialNotification.followNotificationIdFor(
          followerId: actor,
          followeeId: 'b',
        ),
        createdAt: DateTime(2026, 8, 7, 10),
      );
    }

    final coordinator = SocialNotificationCoordinator(
      notificationService: notif,
      friendshipService: friendship,
      bannerService: bannerService(),
    );
    coordinator.bindUid('b');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(shown.length, 1);
    expect(shown.first.type, NotificationType.follow);
    expect(shown.first.body, '3 people followed you');
    expect(coordinator.unreadCount, 3);

    // Rebuild / re-emit should not replay banners.
    await notif.upsertFollowNotificationForTests(
      recipientId: 'b',
      actorId: 'a',
      notificationId: SocialNotification.followNotificationIdFor(
        followerId: 'a',
        followeeId: 'b',
      ),
      createdAt: DateTime(2026, 8, 7, 10),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(shown.length, 1);

    coordinator.dispose();
  });

  test('cold start activity notifications do not use follow summary', () async {
    final firestore = FakeFirebaseFirestore();
    final friendship = FriendshipService(firestore: firestore);
    final notif = SocialNotificationService(firestore: firestore);
    await friendship.upsertPublicProfile(
      uid: 'actor',
      username: 'nathan',
      displayName: 'Nathan',
    );
    await notif.upsertNotificationForTests(
      SocialNotification(
        id: 'activity-kudos-1',
        recipientId: 'owner',
        actorId: 'actor',
        type: SocialNotificationType.activityKudos,
        createdAt: DateTime(2026, 8, 10, 10),
        activityId: 'activity-1',
      ),
    );
    await notif.upsertNotificationForTests(
      SocialNotification(
        id: 'comment-like-1',
        recipientId: 'owner',
        actorId: 'actor',
        type: SocialNotificationType.commentLike,
        createdAt: DateTime(2026, 8, 10, 11),
        activityId: 'activity-1',
        commentId: 'comment-1',
      ),
    );

    final coordinator = SocialNotificationCoordinator(
      notificationService: notif,
      friendshipService: friendship,
      bannerService: bannerService(),
    );
    coordinator.bindUid('owner');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(shown, hasLength(1));
    expect(shown.single.type, NotificationType.commentLike);
    expect(shown.single.body, 'Nathan liked your comment');
    expect(shown.single.data['followSummaryCount'], isNull);

    coordinator.dispose();
  });

  test('live activity notifications use distinct templates', () async {
    final firestore = FakeFirebaseFirestore();
    final friendship = FriendshipService(firestore: firestore);
    final notif = SocialNotificationService(firestore: firestore);
    await friendship.upsertPublicProfile(
      uid: 'actor',
      username: 'nathan',
      displayName: 'Nathan',
    );

    final coordinator = SocialNotificationCoordinator(
      notificationService: notif,
      friendshipService: friendship,
      bannerService: bannerService(),
    );
    coordinator.bindUid('owner');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final notifications = <SocialNotification>[
      SocialNotification(
        id: 'kudos',
        recipientId: 'owner',
        actorId: 'actor',
        type: SocialNotificationType.activityKudos,
        createdAt: DateTime(2026, 8, 10, 10),
        activityId: 'activity-1',
      ),
      SocialNotification(
        id: 'comment',
        recipientId: 'owner',
        actorId: 'actor',
        type: SocialNotificationType.activityComment,
        createdAt: DateTime(2026, 8, 10, 11),
        activityId: 'activity-1',
        commentId: 'comment-1',
      ),
      SocialNotification(
        id: 'reply',
        recipientId: 'owner',
        actorId: 'actor',
        type: SocialNotificationType.commentReply,
        createdAt: DateTime(2026, 8, 10, 12),
        activityId: 'activity-1',
        commentId: 'reply-1',
      ),
      SocialNotification(
        id: 'comment-like',
        recipientId: 'owner',
        actorId: 'actor',
        type: SocialNotificationType.commentLike,
        createdAt: DateTime(2026, 8, 10, 13),
        activityId: 'activity-1',
        commentId: 'comment-1',
      ),
    ];

    for (final notification in notifications) {
      await notif.upsertNotificationForTests(notification);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    expect(
      shown.map((notification) => notification.body),
      containsAll(<String>[
        'Nathan gave Glaze to your activity',
        'Nathan commented on your activity',
        'Nathan replied to your comment',
        'Nathan liked your comment',
      ]),
    );
    expect(shown.map((notification) => notification.type), [
      NotificationType.kudos,
      NotificationType.comment,
      NotificationType.commentReply,
      NotificationType.commentLike,
    ]);

    coordinator.dispose();
  });

  test('live follow after cold start shows single banner', () async {
    final firestore = FakeFirebaseFirestore();
    final friendship = FriendshipService(firestore: firestore);
    final notif = SocialNotificationService(firestore: firestore);
    await friendship.upsertPublicProfile(
      uid: 'a',
      username: 'a',
      displayName: 'Alice',
    );

    final coordinator = SocialNotificationCoordinator(
      notificationService: notif,
      friendshipService: friendship,
      bannerService: bannerService(),
    );
    coordinator.bindUid('b');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(shown, isEmpty);

    await notif.upsertFollowNotificationForTests(
      recipientId: 'b',
      actorId: 'a',
      notificationId: SocialNotification.followNotificationIdFor(
        followerId: 'a',
        followeeId: 'b',
      ),
      createdAt: DateTime(2026, 8, 7, 11),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(shown.length, 1);
    expect(shown.first.body, 'Alice followed you');
    expect(coordinator.hasUnread, isTrue);

    coordinator.dispose();
  });

  test(
    'refollow with same row id and fresh timestamp shows new banner',
    () async {
      final firestore = FakeFirebaseFirestore();
      final friendship = FriendshipService(firestore: firestore);
      final notif = SocialNotificationService(firestore: firestore);
      await friendship.upsertPublicProfile(
        uid: 'a',
        username: 'a',
        displayName: 'Alice',
      );

      final coordinator = SocialNotificationCoordinator(
        notificationService: notif,
        friendshipService: friendship,
        bannerService: bannerService(),
      );
      coordinator.bindUid('b');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final id = SocialNotification.followNotificationIdFor(
        followerId: 'a',
        followeeId: 'b',
      );
      await notif.upsertFollowNotificationForTests(
        recipientId: 'b',
        actorId: 'a',
        notificationId: id,
        createdAt: DateTime(2026, 8, 7, 11),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await firestore
          .collection('profiles')
          .doc('b')
          .collection('notifications')
          .doc(id)
          .delete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await notif.upsertFollowNotificationForTests(
        recipientId: 'b',
        actorId: 'a',
        notificationId: id,
        createdAt: DateTime(2026, 8, 7, 12),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(shown.length, 2);
      expect(shown.every((item) => item.body == 'Alice followed you'), isTrue);

      coordinator.dispose();
    },
  );

  test('account switch disposes A and surfaces B unread summary', () async {
    final firestore = FakeFirebaseFirestore();
    final friendship = FriendshipService(firestore: firestore);
    final notif = SocialNotificationService(firestore: firestore);
    await friendship.upsertPublicProfile(
      uid: 'alice',
      username: 'alice',
      displayName: 'Alice',
    );
    await friendship.upsertPublicProfile(
      uid: 'bob',
      username: 'bob',
      displayName: 'Bob',
    );
    await friendship.upsertPublicProfile(
      uid: 'cara',
      username: 'cara',
      displayName: 'Cara',
    );

    // Preload B's unread follows while A is the active session.
    await notif.upsertFollowNotificationForTests(
      recipientId: 'bob',
      actorId: 'alice',
      notificationId: SocialNotification.followNotificationIdFor(
        followerId: 'alice',
        followeeId: 'bob',
      ),
      createdAt: DateTime(2026, 8, 7, 10),
    );
    await notif.upsertFollowNotificationForTests(
      recipientId: 'bob',
      actorId: 'cara',
      notificationId: SocialNotification.followNotificationIdFor(
        followerId: 'cara',
        followeeId: 'bob',
      ),
      createdAt: DateTime(2026, 8, 7, 11),
    );

    final coordinator = SocialNotificationCoordinator(
      notificationService: notif,
      friendshipService: friendship,
      bannerService: bannerService(),
    );

    coordinator.bindUid('alice');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(shown, isEmpty);
    expect(coordinator.boundUid, 'alice');
    expect(coordinator.unreadCount, 0);

    // Logout then login as Bob without process restart.
    coordinator.bindUid(null);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(coordinator.boundUid, isNull);
    expect(coordinator.hasUnread, isFalse);

    coordinator.bindUid('bob');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(coordinator.boundUid, 'bob');
    expect(shown.length, 1);
    expect(shown.first.body, '2 people followed you');
    expect(coordinator.unreadCount, 2);
    expect(coordinator.hasUnread, isTrue);

    // A's empty session must not suppress Bob's ids.
    coordinator.dispose();
  });

  test(
    'stale async work from previous UID does not banner after switch',
    () async {
      final firestore = FakeFirebaseFirestore();
      final friendship = _SlowFriendshipService(firestore);
      final notif = SocialNotificationService(firestore: firestore);
      await friendship.upsertPublicProfile(
        uid: 'alice',
        username: 'alice',
        displayName: 'Alice',
      );
      await friendship.upsertPublicProfile(
        uid: 'peer',
        username: 'peer',
        displayName: 'Peer',
      );

      final coordinator = SocialNotificationCoordinator(
        notificationService: notif,
        friendshipService: friendship,
        bannerService: bannerService(),
      );

      coordinator.bindUid('alice');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      await notif.upsertFollowNotificationForTests(
        recipientId: 'alice',
        actorId: 'peer',
        notificationId: SocialNotification.followNotificationIdFor(
          followerId: 'peer',
          followeeId: 'alice',
        ),
        createdAt: DateTime(2026, 8, 7, 12),
      );

      // Switch while getPublicProfile is still delayed for Alice's cold start.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      coordinator.bindUid('bob');
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(shown.where((n) => n.body.contains('Peer')), isEmpty);
      expect(coordinator.boundUid, 'bob');
      expect(coordinator.unreadCount, 0);

      coordinator.dispose();
    },
  );
}

class _CapturingBannerService implements NotificationService {
  _CapturingBannerService(this.shown);

  final List<AppNotification> shown;

  @override
  Future<void> show(AppNotification notification) async {
    shown.add(notification);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Delays [getPublicProfile] so bind generation races can be asserted.
class _SlowFriendshipService extends FriendshipService {
  _SlowFriendshipService(FirebaseFirestore firestore)
    : super(firestore: firestore);

  @override
  Future<PublicProfile?> getPublicProfile(String uid) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return super.getPublicProfile(uid);
  }
}
