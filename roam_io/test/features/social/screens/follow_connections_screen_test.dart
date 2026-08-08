/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Widget tests for FollowConnectionsScreen list membership, auth-user
 *   Follow / Following actions, own-followers Remove, unfollow disappearance,
 *   and row navigation.
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
import 'package:roam_io/features/social/screens/follow_connections_screen.dart';
import 'package:roam_io/features/social/screens/other_user_profile_screen.dart';

import '../../../support/fake_firebase_user.dart';

void main() {
  Future<void> pumpList(
    WidgetTester tester, {
    required FollowConnectionsMode mode,
    required String selectedUserId,
    required FollowService follow,
    required FriendshipService friendship,
  }) async {
    final auth = AuthProvider(authRepository: _ListAuthRepository());
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          home: FollowConnectionsScreen(
            selectedUserId: selectedUserId,
            mode: mode,
            followService: follow,
            friendshipService: friendship,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('following list uses selectedUserId membership', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final friendship = FriendshipService(firestore: firestore);
    final follow = FollowService(firestore: firestore);
    await friendship.upsertPublicProfile(
      uid: 'jacob',
      username: 'jacob',
      displayName: 'Jacob',
    );
    await friendship.upsertPublicProfile(
      uid: 'nathan',
      username: 'nathan',
      displayName: 'Nathan',
    );
    await friendship.upsertPublicProfile(
      uid: 'sonia',
      username: 'sonia',
      displayName: 'Sonia',
    );
    // Jacob follows Nathan; current-user follows Sonia only.
    await follow.follow(followerId: 'jacob', followeeId: 'nathan');
    await follow.follow(followerId: 'current-user', followeeId: 'sonia');

    await pumpList(
      tester,
      mode: FollowConnectionsMode.following,
      selectedUserId: 'jacob',
      follow: follow,
      friendship: friendship,
    );

    expect(find.text('Nathan'), findsOneWidget);
    expect(find.text('Sonia'), findsNothing);
    // Current user does not follow Nathan yet.
    expect(find.widgetWithText(FilledButton, 'Follow'), findsOneWidget);
  });

  testWidgets('followers list button uses authenticated follow state', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final friendship = FriendshipService(firestore: firestore);
    final follow = FollowService(firestore: firestore);
    await friendship.upsertPublicProfile(
      uid: 'jacob',
      username: 'jacob',
      displayName: 'Jacob',
    );
    await friendship.upsertPublicProfile(
      uid: 'nathan',
      username: 'nathan',
      displayName: 'Nathan',
    );
    await friendship.upsertPublicProfile(
      uid: 'sonia',
      username: 'sonia',
      displayName: 'Sonia',
    );
    await follow.follow(followerId: 'nathan', followeeId: 'jacob');
    await follow.follow(followerId: 'sonia', followeeId: 'jacob');
    await follow.follow(followerId: 'current-user', followeeId: 'nathan');

    await pumpList(
      tester,
      mode: FollowConnectionsMode.followers,
      selectedUserId: 'jacob',
      follow: follow,
      friendship: friendship,
    );

    expect(find.text('Nathan'), findsOneWidget);
    expect(find.text('Sonia'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Following'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Follow'), findsOneWidget);
  });

  testWidgets('unfollowing from my following list removes the row', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final friendship = FriendshipService(firestore: firestore);
    final follow = FollowService(firestore: firestore);
    await friendship.upsertPublicProfile(
      uid: 'jacob',
      username: 'jacob',
      displayName: 'Jacob',
    );
    await follow.follow(followerId: 'current-user', followeeId: 'jacob');

    await pumpList(
      tester,
      mode: FollowConnectionsMode.following,
      selectedUserId: 'current-user',
      follow: follow,
      friendship: friendship,
    );

    expect(find.text('Jacob'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Following'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Jacob'), findsNothing);
    expect(find.text('Not following anyone yet'), findsOneWidget);
    expect(
      await firestore
          .collection(FollowService.followsCollection)
          .doc(FollowService.followIdFor('current-user', 'jacob'))
          .get()
          .then((doc) => doc.exists),
      isFalse,
    );
  });

  testWidgets('row tap opens other user profile independently of button', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final friendship = FriendshipService(firestore: firestore);
    final follow = FollowService(firestore: firestore);
    await friendship.upsertPublicProfile(
      uid: 'jacob',
      username: 'jacob',
      displayName: 'Jacob',
    );
    await follow.follow(followerId: 'current-user', followeeId: 'jacob');

    await pumpList(
      tester,
      mode: FollowConnectionsMode.following,
      selectedUserId: 'current-user',
      follow: follow,
      friendship: friendship,
    );

    await tester.tap(find.text('Jacob'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(OtherUserProfileScreen), findsOneWidget);
    expect(
      await firestore
          .collection(FollowService.followsCollection)
          .doc(FollowService.followIdFor('current-user', 'jacob'))
          .get()
          .then((doc) => doc.exists),
      isTrue,
    );
  });

  testWidgets('own followers list shows capsule Remove and removes follower', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final friendship = FriendshipService(firestore: firestore);
    final follow = FollowService(firestore: firestore);
    await friendship.upsertPublicProfile(
      uid: 'jacob',
      username: 'jacob',
      displayName: 'Jacob',
    );
    await follow.follow(followerId: 'jacob', followeeId: 'current-user');

    await pumpList(
      tester,
      mode: FollowConnectionsMode.followers,
      selectedUserId: 'current-user',
      follow: follow,
      friendship: friendship,
    );

    expect(find.text('Jacob'), findsOneWidget);
    final removeButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Remove'),
    );
    expect(
      removeButton.style?.shape?.resolve(const <WidgetState>{}),
      isA<StadiumBorder>(),
    );

    final followButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Follow'),
    );
    expect(
      followButton.style?.shape?.resolve(const <WidgetState>{}),
      isA<StadiumBorder>(),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Remove'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Jacob'), findsNothing);
    expect(find.text('No followers yet'), findsOneWidget);
    expect(
      await firestore
          .collection(FollowService.followsCollection)
          .doc(FollowService.followIdFor('jacob', 'current-user'))
          .get()
          .then((doc) => doc.exists),
      isFalse,
    );
  });

  testWidgets(
    'unfollow from opened profile empties underlying Following list',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final friendship = FriendshipService(firestore: firestore);
      final follow = FollowService(firestore: firestore);
      await friendship.upsertPublicProfile(
        uid: 'jacob',
        username: 'jacob',
        displayName: 'Jacob',
      );
      await follow.follow(followerId: 'current-user', followeeId: 'jacob');

      final auth = AuthProvider(authRepository: _ListAuthRepository());
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
            home: FollowConnectionsScreen(
              selectedUserId: 'current-user',
              mode: FollowConnectionsMode.following,
              followService: follow,
              friendshipService: friendship,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Jacob'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Following'), findsOneWidget);

      await tester.tap(find.text('Jacob'));
      await tester.pumpAndSettle();
      expect(find.byType(OtherUserProfileScreen), findsOneWidget);
      expect(find.text('Jacob'), findsWidgets);

      final profileFollowing = find.descendant(
        of: find.byType(OtherUserProfileScreen),
        matching: find.widgetWithText(OutlinedButton, 'Following'),
      );
      expect(profileFollowing, findsOneWidget);
      await tester.ensureVisible(profileFollowing);
      await tester.tap(profileFollowing);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(OtherUserProfileScreen),
          matching: find.widgetWithText(FilledButton, 'Follow'),
        ),
        findsOneWidget,
      );
      expect(await follow.watchFollowingCount('current-user').first, 0);
      expect(await follow.watchFollowerCount('jacob').first, 0);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(FollowConnectionsScreen), findsOneWidget);
      expect(find.text('Jacob'), findsNothing);
      expect(find.text('Not following anyone yet'), findsOneWidget);
    },
  );

  testWidgets('other users followers list does not show Remove', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final friendship = FriendshipService(firestore: firestore);
    final follow = FollowService(firestore: firestore);
    await friendship.upsertPublicProfile(
      uid: 'jacob',
      username: 'jacob',
      displayName: 'Jacob',
    );
    await friendship.upsertPublicProfile(
      uid: 'nathan',
      username: 'nathan',
      displayName: 'Nathan',
    );
    await follow.follow(followerId: 'nathan', followeeId: 'jacob');

    await pumpList(
      tester,
      mode: FollowConnectionsMode.followers,
      selectedUserId: 'jacob',
      follow: follow,
      friendship: friendship,
    );

    expect(find.text('Nathan'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Remove'), findsNothing);
  });
}

class _ListAuthRepository implements AuthRepository {
  _ListAuthRepository()
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
