/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Widget tests for NotificationsScreen list, mark-read, Follow Back / Remove
 *   chrome, and empty state. Relationship mutations are covered in service tests.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';
import 'package:roam_io/features/social/data/follow_service.dart';
import 'package:roam_io/features/social/data/friendship_service.dart';
import 'package:roam_io/features/social/data/social_notification_service.dart';
import 'package:roam_io/features/social/screens/notifications_screen.dart';

import '../../../support/fake_firebase_user.dart';

void main() {
  Future<void> pumpNotifScreen(
    WidgetTester tester, {
    required AuthProvider auth,
    required SocialNotificationService notif,
    required FollowService follow,
    required FriendshipService friendship,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          home: NotificationsScreen(
            notificationService: notif,
            followService: follow,
            friendshipService: friendship,
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
      notificationId: FollowService.followIdFor('actor', 'current-user'),
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
      notificationId: FollowService.followIdFor('actor', 'current-user'),
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
