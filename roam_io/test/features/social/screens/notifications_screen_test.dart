/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 29 August 2026 — Sanjevan Rajasegar
 * Description:
 *   Widget tests for NotificationsScreen list, mark-read, Follow Back /
 *   Following unfollow, follow request actions, stale request rows, and empty
 *   state.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/activity_feed/data/activity_feed_service.dart';
import 'package:roam_io/features/activity_feed/models/activity_feed_item.dart';
import 'package:roam_io/features/activity_feed/screens/comments_screen.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';
import 'package:roam_io/features/social/data/follow_request_service.dart';
import 'package:roam_io/features/social/data/follow_service.dart';
import 'package:roam_io/features/social/data/friendship_service.dart';
import 'package:roam_io/features/social/data/social_notification_service.dart';
import 'package:roam_io/features/social/domain/social_notification.dart';
import 'package:roam_io/features/social/screens/notifications_screen.dart';
import 'package:roam_io/features/social/screens/other_user_profile_screen.dart';
import 'package:roam_io/theme/app_colours.dart';

import '../../../support/fake_firebase_user.dart';

void main() {
  Color? buttonBackground(WidgetTester tester, Finder finder) {
    final button = tester.widget<ButtonStyleButton>(finder);
    return button.style?.backgroundColor?.resolve(<WidgetState>{});
  }

  Future<void> pumpNotifScreen(
    WidgetTester tester, {
    required AuthProvider auth,
    required SocialNotificationService notif,
    required FollowService follow,
    required FriendshipService friendship,
    ActivityFeedService? activityFeed,
    FollowRequestService? requests,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          home: NotificationsScreen(
            notificationService: notif,
            followService: follow,
            followRequestService: requests,
            friendshipService: friendship,
            activityFeedService: activityFeed,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('row shows actor message, Follow Back, and marks read on open', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final friendship = FriendshipService(firestore: firestore);
    final notif = SocialNotificationService(firestore: firestore);
    final follow = FollowService(firestore: firestore);
    await friendship.upsertPublicProfile(
      uid: 'actor',
      username: 'jacob',
      displayName: 'Jacob',
    );
    await notif.upsertFollowNotificationForTests(
      recipientId: 'current-user',
      actorId: 'actor',
      notificationId: SocialNotification.followNotificationIdFor(
        followerId: 'actor',
        followeeId: 'current-user',
      ),
    );

    final auth = AuthProvider(authRepository: _NotifAuthRepository());
    await pumpNotifScreen(
      tester,
      auth: auth,
      notif: notif,
      follow: follow,
      friendship: friendship,
    );

    expect(find.textContaining('Jacob followed you'), findsOneWidget);
    expect(find.text('Follow Back'), findsOneWidget);
    expect(find.byTooltip('More'), findsOneWidget);
    expect(await notif.watchUnreadCount('current-user').first, 0);
    auth.dispose();
  });

  testWidgets('Remove follower appears in overflow menu', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final friendship = FriendshipService(firestore: firestore);
    final notif = SocialNotificationService(firestore: firestore);
    final follow = FollowService(firestore: firestore);
    await friendship.upsertPublicProfile(
      uid: 'actor',
      username: 'jacob',
      displayName: 'Jacob',
    );
    await notif.upsertFollowNotificationForTests(
      recipientId: 'current-user',
      actorId: 'actor',
      notificationId: SocialNotification.followNotificationIdFor(
        followerId: 'actor',
        followeeId: 'current-user',
      ),
    );

    final auth = AuthProvider(authRepository: _NotifAuthRepository());
    await pumpNotifScreen(
      tester,
      auth: auth,
      notif: notif,
      follow: follow,
      friendship: friendship,
    );

    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Remove follower'), findsOneWidget);
    auth.dispose();
  });

  testWidgets('tapping notification body opens actor profile', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final friendship = FriendshipService(firestore: firestore);
    final notif = SocialNotificationService(firestore: firestore);
    final follow = FollowService(firestore: firestore);
    await friendship.upsertPublicProfile(
      uid: 'actor',
      username: 'jacob',
      displayName: 'Jacob',
    );
    await notif.upsertFollowNotificationForTests(
      recipientId: 'current-user',
      actorId: 'actor',
      notificationId: SocialNotification.followNotificationIdFor(
        followerId: 'actor',
        followeeId: 'current-user',
      ),
    );

    final auth = AuthProvider(authRepository: _NotifAuthRepository());
    await pumpNotifScreen(
      tester,
      auth: auth,
      notif: notif,
      follow: follow,
      friendship: friendship,
    );

    await tester.tap(find.textContaining('Jacob followed you'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(OtherUserProfileScreen), findsOneWidget);
    auth.dispose();
  });

  testWidgets('notification action tap does not open actor profile', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final friendship = FriendshipService(firestore: firestore);
    final notif = SocialNotificationService(firestore: firestore);
    final follow = FollowService(firestore: firestore);
    await friendship.upsertPublicProfile(
      uid: 'actor',
      username: 'jacob',
      displayName: 'Jacob',
    );
    await notif.upsertFollowNotificationForTests(
      recipientId: 'current-user',
      actorId: 'actor',
      notificationId: SocialNotification.followNotificationIdFor(
        followerId: 'actor',
        followeeId: 'current-user',
      ),
    );

    final auth = AuthProvider(authRepository: _NotifAuthRepository());
    await pumpNotifScreen(
      tester,
      auth: auth,
      notif: notif,
      follow: follow,
      friendship: friendship,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Follow Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(OtherUserProfileScreen), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Following'), findsOneWidget);
    expect(
      buttonBackground(
        tester,
        find.widgetWithText(OutlinedButton, 'Following'),
      ),
      AppColors.cream,
    );
    auth.dispose();
  });

  testWidgets('Following on notification row unfollows immediately', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final friendship = FriendshipService(firestore: firestore);
    final notif = SocialNotificationService(firestore: firestore);
    final follow = FollowService(firestore: firestore);
    await friendship.upsertPublicProfile(
      uid: 'actor',
      username: 'jacob',
      displayName: 'Jacob',
    );
    await notif.upsertFollowNotificationForTests(
      recipientId: 'current-user',
      actorId: 'actor',
      notificationId: SocialNotification.followNotificationIdFor(
        followerId: 'actor',
        followeeId: 'current-user',
      ),
    );
    await follow.follow(followerId: 'current-user', followeeId: 'actor');

    final auth = AuthProvider(authRepository: _NotifAuthRepository());
    await pumpNotifScreen(
      tester,
      auth: auth,
      notif: notif,
      follow: follow,
      friendship: friendship,
    );

    expect(find.widgetWithText(OutlinedButton, 'Following'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Following'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Follow Back'), findsOneWidget);
    expect(
      await firestore
          .collection(FollowService.followsCollection)
          .doc(FollowService.followIdFor('current-user', 'actor'))
          .get()
          .then((doc) => doc.exists),
      isFalse,
    );
    auth.dispose();
  });

  testWidgets('shows empty copy when inbox is empty', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final auth = AuthProvider(authRepository: _NotifAuthRepository());
    await pumpNotifScreen(
      tester,
      auth: auth,
      notif: SocialNotificationService(firestore: firestore),
      follow: FollowService(firestore: firestore),
      friendship: FriendshipService(firestore: firestore),
    );
    expect(find.text('No notifications yet'), findsOneWidget);
    auth.dispose();
  });

  testWidgets('activity notification row opens comments destination', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final friendship = FriendshipService(firestore: firestore);
    final notif = SocialNotificationService(firestore: firestore);
    final follow = FollowService(firestore: firestore);
    await friendship.upsertPublicProfile(
      uid: 'actor',
      username: 'nathan',
      displayName: 'Nathan',
    );
    await notif.upsertNotificationForTests(
      SocialNotification(
        id: 'activity-comment-1',
        recipientId: 'current-user',
        actorId: 'actor',
        type: SocialNotificationType.activityComment,
        createdAt: DateTime(2026, 8, 10),
        activityId: 'activity-1',
        commentId: 'comment-1',
      ),
    );

    final auth = AuthProvider(authRepository: _NotifAuthRepository());
    await pumpNotifScreen(
      tester,
      auth: auth,
      notif: notif,
      follow: follow,
      friendship: friendship,
      activityFeed: _FakeActivityFeedService(),
    );

    expect(
      find.textContaining('Nathan commented on your activity'),
      findsOneWidget,
    );
    await tester.tap(find.textContaining('Nathan commented on your activity'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CommentsScreen), findsOneWidget);
    expect(find.byType(OtherUserProfileScreen), findsNothing);
    auth.dispose();
  });

  testWidgets('accepts incoming private follow request from notification row', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final friendship = FriendshipService(firestore: firestore);
    final notif = SocialNotificationService(firestore: firestore);
    final follow = FollowService(firestore: firestore);
    final requests = FollowRequestService(firestore: firestore);
    await friendship.upsertPublicProfile(
      uid: 'current-user',
      username: 'current',
      displayName: 'Current',
      isPrivateAccount: true,
    );
    await friendship.upsertPublicProfile(
      uid: 'actor',
      username: 'jacob',
      displayName: 'Jacob',
    );
    await follow.followOrRequest(
      followerId: 'actor',
      followeeId: 'current-user',
    );

    final auth = AuthProvider(authRepository: _NotifAuthRepository());
    await pumpNotifScreen(
      tester,
      auth: auth,
      notif: notif,
      follow: follow,
      friendship: friendship,
      requests: requests,
    );

    expect(
      find.textContaining('Jacob requested to follow you'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Accept'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.widgetWithText(FilledButton, 'Accept'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Decline'), findsNothing);
    expect(find.textContaining('Jacob followed you'), findsOneWidget);
    expect(find.text('Follow Back'), findsOneWidget);
    expect(
      await firestore
          .collection(FollowService.followsCollection)
          .doc(FollowService.followIdFor('actor', 'current-user'))
          .get()
          .then((doc) => doc.exists),
      isTrue,
    );
    expect(
      await firestore
          .collection(FollowRequestService.followRequestsCollection)
          .doc(FollowRequestService.requestIdFor('actor', 'current-user'))
          .get()
          .then((doc) => doc.exists),
      isFalse,
    );
    expect(
      (await notif.watchRecent('actor').first).single.type.name,
      'followRequestAccepted',
    );
    final currentRows = await notif.watchRecent('current-user').first;
    expect(currentRows, hasLength(1));
    expect(currentRows.single.id, 'follow_actor_current-user');
    expect(currentRows.single.type.name, 'follow');

    await tester.tap(find.widgetWithText(FilledButton, 'Follow Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.widgetWithText(OutlinedButton, 'Following'), findsOneWidget);
    expect(
      await firestore
          .collection(FollowRequestService.followRequestsCollection)
          .doc(FollowRequestService.requestIdFor('current-user', 'actor'))
          .get()
          .then((doc) => doc.exists),
      isFalse,
    );
    expect(
      await firestore
          .collection(FollowService.followsCollection)
          .doc(FollowService.followIdFor('current-user', 'actor'))
          .get()
          .then((doc) => doc.exists),
      isTrue,
    );
    auth.dispose();
  });

  testWidgets(
    'declines incoming private follow request from notification row',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final friendship = FriendshipService(firestore: firestore);
      final notif = SocialNotificationService(firestore: firestore);
      final follow = FollowService(firestore: firestore);
      final requests = FollowRequestService(firestore: firestore);
      await friendship.upsertPublicProfile(
        uid: 'current-user',
        username: 'current',
        displayName: 'Current',
        isPrivateAccount: true,
      );
      await friendship.upsertPublicProfile(
        uid: 'actor',
        username: 'jacob',
        displayName: 'Jacob',
      );
      await follow.followOrRequest(
        followerId: 'actor',
        followeeId: 'current-user',
      );

      final auth = AuthProvider(authRepository: _NotifAuthRepository());
      await pumpNotifScreen(
        tester,
        auth: auth,
        notif: notif,
        follow: follow,
        friendship: friendship,
        requests: requests,
      );

      expect(find.widgetWithText(OutlinedButton, 'Decline'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Decline'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.widgetWithText(FilledButton, 'Accept'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Decline'), findsNothing);
      expect(
        await firestore
            .collection(FollowService.followsCollection)
            .doc(FollowService.followIdFor('actor', 'current-user'))
            .get()
            .then((doc) => doc.exists),
        isFalse,
      );
      expect(await notif.watchRecent('actor').first, isEmpty);
      expect(await notif.watchRecent('current-user').first, isEmpty);
      auth.dispose();
    },
  );

  testWidgets('stale follow request notification is non-actionable', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final friendship = FriendshipService(firestore: firestore);
    final notif = SocialNotificationService(firestore: firestore);
    final follow = FollowService(firestore: firestore);
    final requests = FollowRequestService(firestore: firestore);
    await friendship.upsertPublicProfile(
      uid: 'actor',
      username: 'jacob',
      displayName: 'Jacob',
    );
    await notif.upsertNotificationForTests(
      SocialNotification(
        id: FollowRequestService.requestNotificationIdFor(
          'actor',
          'current-user',
        ),
        recipientId: 'current-user',
        actorId: 'actor',
        type: SocialNotificationType.followRequest,
        createdAt: DateTime(2026, 8, 9),
      ),
    );

    final auth = AuthProvider(authRepository: _NotifAuthRepository());
    await pumpNotifScreen(
      tester,
      auth: auth,
      notif: notif,
      follow: follow,
      friendship: friendship,
      requests: requests,
    );

    expect(
      find.textContaining('Jacob requested to follow you'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Accept'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Decline'), findsNothing);
    expect(
      await firestore
          .collection(FollowService.followsCollection)
          .doc(FollowService.followIdFor('actor', 'current-user'))
          .get()
          .then((doc) => doc.exists),
      isFalse,
    );
    auth.dispose();
  });
}

class _NotifAuthRepository implements AuthRepository {
  _NotifAuthRepository()
    : _user = FakeFirebaseUser(
        uid: 'current-user',
        email: 'current@test.com',
        emailVerified: true,
      ),
      _profile = ProfileModel(
        uid: 'current-user',
        username: 'current',
        displayName: 'Current User',
        email: 'current@test.com',
        createdAt: DateTime(2026, 8, 7),
        updatedAt: DateTime(2026, 8, 7),
      );

  final firebase_auth.User _user;
  final ProfileModel _profile;

  @override
  Stream<firebase_auth.User?> authStateChanges() async* {
    yield _user;
  }

  @override
  firebase_auth.User? get currentUser => _user;

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<ProfileModel?> getCurrentUserProfile() async => _profile;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeActivityFeedService implements ActivityFeedService {
  @override
  Stream<ActivityFeedItem?> watchActivity(String activityId) {
    return Stream<ActivityFeedItem?>.value(
      ActivityFeedItem(
        id: activityId,
        ownerId: 'current-user',
        displayName: 'Current User',
        timestampLabel: 'Today',
        title: 'X Activity 1',
        kind: ActivityFeedKind.exploration,
        metrics: const <ActivityFeedMetric>[],
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
