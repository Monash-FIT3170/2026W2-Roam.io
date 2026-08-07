/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Unit tests for public user search, friend requests, crossed requests,
 *   accept/decline handling and reactive relationship state.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/social/data/friendship_service.dart';
import 'package:roam_io/features/social/domain/friend_relationship.dart';
import 'package:roam_io/features/social/domain/friend_request.dart';

void main() {
  group('FriendshipService search', () {
    test('searches public profiles by display name and username', () async {
      final firestore = FakeFirebaseFirestore();
      final service = FriendshipService(firestore: firestore);

      await service.upsertPublicProfile(
        uid: 'current-user',
        username: 'sanj',
        displayName: 'Sanjevan Current',
      );
      await service.upsertPublicProfile(
        uid: 'nathan',
        username: 'nathan',
        displayName: 'Nathan Nunes',
      );
      await service.upsertPublicProfile(
        uid: 'sanjevan',
        username: 'sanjevanr_test',
        displayName: 'Sanjevan Rajasegar',
      );

      final byName = await service.searchUsers(
        query: 'SANJ',
        currentUserId: 'current-user',
      );
      final byUsername = await service.searchUsers(
        query: 'nath',
        currentUserId: 'current-user',
      );

      expect(byName.map((profile) => profile.uid), ['sanjevan']);
      expect(byUsername.map((profile) => profile.uid), ['nathan']);
    });

    test('merges duplicate display-name and username matches', () async {
      final service = FriendshipService(firestore: FakeFirebaseFirestore());
      await service.upsertPublicProfile(
        uid: 'sanj-user',
        username: 'sanj',
        displayName: 'Sanj Person',
      );

      final results = await service.searchUsers(
        query: 'sanj',
        currentUserId: 'current-user',
      );

      expect(results.map((profile) => profile.uid), ['sanj-user']);
    });

    test('searches from one character and ignores empty queries', () async {
      final service = FriendshipService(firestore: FakeFirebaseFirestore());
      await service.upsertPublicProfile(
        uid: 'jacob',
        username: 'jacob_delapaz',
        displayName: 'Jacob de la Paz',
      );

      expect(
        await service.searchUsers(query: '', currentUserId: 'current-user'),
        isEmpty,
      );
      final results = await service.searchUsers(
        query: 'j',
        currentUserId: 'current-user',
      );
      expect(results.map((profile) => profile.uid), ['jacob']);
    });

    test('normalizes leading at-sign usernames for search', () async {
      final service = FriendshipService(firestore: FakeFirebaseFirestore());
      await service.upsertPublicProfile(
        uid: 'jacob',
        username: '@jacob_delapaz',
        displayName: 'Jacob de la Paz',
      );

      final withoutAt = await service.searchUsers(
        query: 'jacob_delapaz',
        currentUserId: 'current-user',
      );
      final withAt = await service.searchUsers(
        query: '@jacob_delapaz',
        currentUserId: 'current-user',
      );

      expect(withoutAt.map((profile) => profile.uid), ['jacob']);
      expect(withAt.map((profile) => profile.uid), ['jacob']);
    });
  });

  group('FriendshipService requests', () {
    test('creates a request and prevents duplicates', () async {
      final service = FriendshipService(firestore: FakeFirebaseFirestore());

      final first = await service.sendRequest(
        senderId: 'user-a',
        recipientId: 'user-b',
      );
      final second = await service.sendRequest(
        senderId: 'user-a',
        recipientId: 'user-b',
      );

      expect(first, SendFriendRequestResult.sent);
      expect(second, SendFriendRequestResult.alreadySent);
    });

    test('prevents self requests and crossed requests', () async {
      final service = FriendshipService(firestore: FakeFirebaseFirestore());

      final self = await service.sendRequest(
        senderId: 'user-a',
        recipientId: 'user-a',
      );
      await service.sendRequest(senderId: 'user-a', recipientId: 'user-b');
      final crossed = await service.sendRequest(
        senderId: 'user-b',
        recipientId: 'user-a',
      );

      expect(self, SendFriendRequestResult.selfRequest);
      expect(crossed, SendFriendRequestResult.incomingRequest);
    });

    test(
      'accept creates a friendship visible in relationship stream',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = FriendshipService(firestore: firestore);
        final pairKey = FriendshipService.pairKeyFor('user-a', 'user-b');

        await service.sendRequest(senderId: 'user-a', recipientId: 'user-b');
        await service.acceptRequest(
          requestId: pairKey,
          currentUserId: 'user-b',
        );

        final requestDoc = await firestore
            .collection(FriendshipService.friendRequestsCollection)
            .doc(pairKey)
            .get();
        final friendshipDoc = await firestore
            .collection(FriendshipService.friendshipsCollection)
            .doc(pairKey)
            .get();
        final relationship = await service
            .watchRelationship(currentUserId: 'user-a', otherUserId: 'user-b')
            .firstWhere(
              (state) => state.status == FriendRelationshipStatus.friends,
            );

        expect(
          requestDoc.data()?['status'],
          FriendRequestStatus.accepted.wireValue,
        );
        expect(friendshipDoc.exists, isTrue);
        expect(relationship.status, FriendRelationshipStatus.friends);
      },
    );

    test('decline clears pending relationship without friendship', () async {
      final firestore = FakeFirebaseFirestore();
      final service = FriendshipService(firestore: firestore);
      final pairKey = FriendshipService.pairKeyFor('user-a', 'user-b');

      await service.sendRequest(senderId: 'user-a', recipientId: 'user-b');
      await service.declineRequest(requestId: pairKey, currentUserId: 'user-b');

      final requestDoc = await firestore
          .collection(FriendshipService.friendRequestsCollection)
          .doc(pairKey)
          .get();
      final friendshipDoc = await firestore
          .collection(FriendshipService.friendshipsCollection)
          .doc(pairKey)
          .get();
      final relationship = await service
          .watchRelationship(currentUserId: 'user-a', otherUserId: 'user-b')
          .firstWhere((state) => state.status == FriendRelationshipStatus.none);

      expect(
        requestDoc.data()?['status'],
        FriendRequestStatus.declined.wireValue,
      );
      expect(friendshipDoc.exists, isFalse);
      expect(relationship.status, FriendRelationshipStatus.none);
    });

    test('declined requests can be sent again', () async {
      final service = FriendshipService(firestore: FakeFirebaseFirestore());
      final pairKey = FriendshipService.pairKeyFor('user-a', 'user-b');

      await service.sendRequest(senderId: 'user-a', recipientId: 'user-b');
      await service.declineRequest(requestId: pairKey, currentUserId: 'user-b');
      final resend = await service.sendRequest(
        senderId: 'user-b',
        recipientId: 'user-a',
      );

      expect(resend, SendFriendRequestResult.sent);
    });
  });
}
