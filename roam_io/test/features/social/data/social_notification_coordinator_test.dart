/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Unit tests for SocialNotificationCoordinator cold-start summary and
 *   live banner dedupe behaviour.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/social/data/follow_service.dart';
import 'package:roam_io/features/social/data/friendship_service.dart';
import 'package:roam_io/features/social/data/social_notification_coordinator.dart';
import 'package:roam_io/features/social/data/social_notification_service.dart';
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
