/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Unit tests for SocialNotificationCoordinator cold-start summary, live
 *   banner dedupe, and auth UID switching (account change on one device).
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/social/data/follow_service.dart';
import 'package:roam_io/features/social/data/friendship_service.dart';
import 'package:roam_io/features/social/data/social_notification_coordinator.dart';
import 'package:roam_io/features/social/data/social_notification_service.dart';
import 'package:roam_io/features/social/domain/public_profile.dart';
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
        notificationId: FollowService.followIdFor(actor, 'b'),
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
      notificationId: FollowService.followIdFor('a', 'b'),
      createdAt: DateTime(2026, 8, 7, 10),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(shown.length, 1);

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
      notificationId: FollowService.followIdFor('a', 'b'),
      createdAt: DateTime(2026, 8, 7, 11),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(shown.length, 1);
    expect(shown.first.body, 'Alice followed you');
    expect(coordinator.hasUnread, isTrue);

    coordinator.dispose();
  });

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
      notificationId: FollowService.followIdFor('alice', 'bob'),
      createdAt: DateTime(2026, 8, 7, 10),
    );
    await notif.upsertFollowNotificationForTests(
      recipientId: 'bob',
      actorId: 'cara',
      notificationId: FollowService.followIdFor('cara', 'bob'),
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

  test('stale async work from previous UID does not banner after switch', () async {
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
      notificationId: FollowService.followIdFor('peer', 'alice'),
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
  });
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
  _SlowFriendshipService(FirebaseFirestore firestore) : super(firestore: firestore);

  @override
  Future<PublicProfile?> getPublicProfile(String uid) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return super.getPublicProfile(uid);
  }
}
