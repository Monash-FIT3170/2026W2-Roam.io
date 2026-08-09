/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Unit tests for private-account Follow Request lifecycle and notifications.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/social/data/follow_request_service.dart';
import 'package:roam_io/features/social/data/follow_service.dart';
import 'package:roam_io/features/social/data/friendship_service.dart';
import 'package:roam_io/features/social/data/social_notification_service.dart';
import 'package:roam_io/features/social/domain/follow_relationship_state.dart';

void main() {
  test(
    'private follow request does not change counts until accepted',
    () async {
      final firestore = FakeFirebaseFirestore();
      final profiles = FriendshipService(firestore: firestore);
      final follow = FollowService(firestore: firestore);
      final requests = FollowRequestService(firestore: firestore);
      final notifications = SocialNotificationService(firestore: firestore);

      await profiles.upsertPublicProfile(
        uid: 'target',
        username: 'target',
        displayName: 'Target',
        isPrivateAccount: true,
      );

      await follow.followOrRequest(followerId: 'viewer', followeeId: 'target');
      await follow.followOrRequest(followerId: 'viewer', followeeId: 'target');

      expect(await follow.watchFollowingCount('viewer').first, 0);
      expect(await follow.watchFollowerCount('target').first, 0);
      expect(
        (await requests.watchOutgoingFollowRequests('viewer').first).single.id,
        FollowRequestService.requestIdFor('viewer', 'target'),
      );
      expect(
        (await notifications.watchRecent('target').first).single.type.name,
        'followRequest',
      );
      expect(await notifications.watchRecent('target').first, hasLength(1));
      expect(
        (await follow
                .watchFollowState(followerId: 'viewer', followeeId: 'target')
                .first)
            .status,
        FollowRelationshipStatus.requested,
      );

      await requests.acceptFollowRequest(
        requestId: FollowRequestService.requestIdFor('viewer', 'target'),
        currentUserId: 'target',
      );

      expect(await follow.watchFollowingCount('viewer').first, 1);
      expect(await follow.watchFollowerCount('target').first, 1);
      expect(
        await requests.watchOutgoingFollowRequests('viewer').first,
        isEmpty,
      );
      expect(
        (await follow
                .watchFollowState(followerId: 'viewer', followeeId: 'target')
                .first)
            .status,
        FollowRelationshipStatus.following,
      );
      expect(
        (await notifications.watchRecent('viewer').first).single.type.name,
        'followRequestAccepted',
      );
      final targetRows = await notifications.watchRecent('target').first;
      expect(targetRows, hasLength(1));
      expect(targetRows.single.type.name, 'follow');
    },
  );

  test(
    'cancel and decline remove requests without notifications to requester',
    () async {
      final firestore = FakeFirebaseFirestore();
      final profiles = FriendshipService(firestore: firestore);
      final follow = FollowService(firestore: firestore);
      final requests = FollowRequestService(firestore: firestore);
      final notifications = SocialNotificationService(firestore: firestore);

      await profiles.upsertPublicProfile(
        uid: 'target',
        username: 'target',
        displayName: 'Target',
        isPrivateAccount: true,
      );

      await follow.followOrRequest(followerId: 'viewer', followeeId: 'target');
      await requests.cancelFollowRequest(
        requesterId: 'viewer',
        targetId: 'target',
      );
      expect(
        await requests.watchIncomingFollowRequests('target').first,
        isEmpty,
      );
      expect(await notifications.watchRecent('viewer').first, isEmpty);
      expect(await notifications.watchRecent('target').first, isEmpty);

      await follow.followOrRequest(followerId: 'viewer', followeeId: 'target');
      await requests.declineFollowRequest(
        requestId: FollowRequestService.requestIdFor('viewer', 'target'),
        currentUserId: 'target',
      );
      expect(
        await requests.watchIncomingFollowRequests('target').first,
        isEmpty,
      );
      expect(await follow.watchFollowerCount('target').first, 0);
      expect(await notifications.watchRecent('viewer').first, isEmpty);
      expect(await notifications.watchRecent('target').first, isEmpty);
    },
  );

  test(
    'pending request stops showing Requested when target becomes public',
    () async {
      final firestore = FakeFirebaseFirestore();
      final profiles = FriendshipService(firestore: firestore);
      final follow = FollowService(firestore: firestore);

      await profiles.upsertPublicProfile(
        uid: 'target',
        username: 'target',
        displayName: 'Target',
        isPrivateAccount: true,
      );

      await follow.followOrRequest(followerId: 'viewer', followeeId: 'target');
      await profiles.upsertPublicProfile(
        uid: 'target',
        username: 'target',
        displayName: 'Target',
        isPrivateAccount: false,
      );

      expect(
        (await follow
                .watchFollowState(followerId: 'viewer', followeeId: 'target')
                .first)
            .status,
        FollowRelationshipStatus.notFollowing,
      );

      await follow.followOrRequest(followerId: 'viewer', followeeId: 'target');
      expect(await follow.watchFollowingCount('viewer').first, 1);
    },
  );

  test(
    'public re-follow recreates one fresh relationship notification',
    () async {
      final firestore = FakeFirebaseFirestore();
      final profiles = FriendshipService(firestore: firestore);
      final follow = FollowService(firestore: firestore);
      final notifications = SocialNotificationService(firestore: firestore);

      await profiles.upsertPublicProfile(
        uid: 'target',
        username: 'target',
        displayName: 'Target',
      );

      await follow.follow(followerId: 'viewer', followeeId: 'target');
      await follow.follow(followerId: 'viewer', followeeId: 'target');
      final firstRows = await notifications.watchRecent('target').first;
      expect(firstRows, hasLength(1));
      expect(firstRows.single.id, 'follow_viewer_target');
      final firstCreatedAt = firstRows.single.createdAt;

      await follow.unfollow(followerId: 'viewer', followeeId: 'target');
      expect(await notifications.watchRecent('target').first, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 1));
      await follow.follow(followerId: 'viewer', followeeId: 'target');

      final rows = await notifications.watchRecent('target').first;
      expect(rows, hasLength(1));
      expect(rows.single.id, 'follow_viewer_target');
      expect(rows.single.type.name, 'follow');
      expect(rows.single.createdAt.isAfter(firstCreatedAt), isTrue);
    },
  );

  test(
    'private re-request after unfollow recreates one relationship row',
    () async {
      final firestore = FakeFirebaseFirestore();
      final profiles = FriendshipService(firestore: firestore);
      final follow = FollowService(firestore: firestore);
      final requests = FollowRequestService(firestore: firestore);
      final notifications = SocialNotificationService(firestore: firestore);

      await profiles.upsertPublicProfile(
        uid: 'target',
        username: 'target',
        displayName: 'Target',
        isPrivateAccount: true,
      );

      await follow.followOrRequest(followerId: 'viewer', followeeId: 'target');
      await requests.acceptFollowRequest(
        requestId: FollowRequestService.requestIdFor('viewer', 'target'),
        currentUserId: 'target',
      );
      final acceptedRows = await notifications.watchRecent('target').first;
      expect(acceptedRows, hasLength(1));
      expect(acceptedRows.single.id, 'follow_viewer_target');
      await follow.unfollow(followerId: 'viewer', followeeId: 'target');
      expect(await notifications.watchRecent('target').first, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 1));
      await follow.followOrRequest(followerId: 'viewer', followeeId: 'target');
      final requestRows = await notifications.watchRecent('target').first;
      expect(requestRows, hasLength(1));
      expect(requestRows.single.id, 'follow_request_viewer_target');
      await requests.acceptFollowRequest(
        requestId: FollowRequestService.requestIdFor('viewer', 'target'),
        currentUserId: 'target',
      );

      final rows = await notifications.watchRecent('target').first;
      expect(rows, hasLength(1));
      expect(rows.single.id, 'follow_viewer_target');
      expect(rows.single.type.name, 'follow');
    },
  );

  test(
    'accepted private request follow back to public requester is immediate',
    () async {
      final firestore = FakeFirebaseFirestore();
      final profiles = FriendshipService(firestore: firestore);
      final follow = FollowService(firestore: firestore);
      final requests = FollowRequestService(firestore: firestore);

      await profiles.upsertPublicProfile(
        uid: 'public-requester',
        username: 'public',
        displayName: 'Public Requester',
        isPrivateAccount: false,
      );
      await profiles.upsertPublicProfile(
        uid: 'private-target',
        username: 'private',
        displayName: 'Private Target',
        isPrivateAccount: true,
      );

      await follow.followOrRequest(
        followerId: 'public-requester',
        followeeId: 'private-target',
      );
      expect(
        (await follow
                .watchFollowState(
                  followerId: 'public-requester',
                  followeeId: 'private-target',
                )
                .first)
            .status,
        FollowRelationshipStatus.requested,
      );

      await requests.acceptFollowRequest(
        requestId: FollowRequestService.requestIdFor(
          'public-requester',
          'private-target',
        ),
        currentUserId: 'private-target',
      );
      await follow.followOrRequest(
        followerId: 'private-target',
        followeeId: 'public-requester',
      );

      expect(await follow.watchFollowingCount('public-requester').first, 1);
      expect(await follow.watchFollowerCount('private-target').first, 1);
      expect(await follow.watchFollowingCount('private-target').first, 1);
      expect(await follow.watchFollowerCount('public-requester').first, 1);
      expect(
        await requests
            .watchPendingBetween(
              requesterId: 'private-target',
              targetId: 'public-requester',
            )
            .first,
        isNull,
      );
      expect(
        (await follow
                .watchFollowState(
                  followerId: 'private-target',
                  followeeId: 'public-requester',
                )
                .first)
            .status,
        FollowRelationshipStatus.following,
      );
    },
  );

  test(
    'accepted private request follow back to private requester becomes requested',
    () async {
      final firestore = FakeFirebaseFirestore();
      final profiles = FriendshipService(firestore: firestore);
      final follow = FollowService(firestore: firestore);
      final requests = FollowRequestService(firestore: firestore);

      await profiles.upsertPublicProfile(
        uid: 'private-requester',
        username: 'requester',
        displayName: 'Private Requester',
        isPrivateAccount: true,
      );
      await profiles.upsertPublicProfile(
        uid: 'private-target',
        username: 'target',
        displayName: 'Private Target',
        isPrivateAccount: true,
      );

      await follow.followOrRequest(
        followerId: 'private-requester',
        followeeId: 'private-target',
      );
      await requests.acceptFollowRequest(
        requestId: FollowRequestService.requestIdFor(
          'private-requester',
          'private-target',
        ),
        currentUserId: 'private-target',
      );
      await follow.followOrRequest(
        followerId: 'private-target',
        followeeId: 'private-requester',
      );

      expect(
        (await follow
                .watchFollowState(
                  followerId: 'private-target',
                  followeeId: 'private-requester',
                )
                .first)
            .status,
        FollowRelationshipStatus.requested,
      );
      expect(await follow.watchFollowingCount('private-target').first, 0);
      expect(
        await requests
            .watchPendingBetween(
              requesterId: 'private-target',
              targetId: 'private-requester',
            )
            .first,
        isNotNull,
      );
    },
  );
}
