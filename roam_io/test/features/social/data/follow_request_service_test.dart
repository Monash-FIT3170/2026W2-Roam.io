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
}
