import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/party/data/party_invite_service.dart';
import 'package:roam_io/features/party/data/party_service.dart';
import 'package:roam_io/features/social/data/friendship_service.dart';

void main() {
  test(
    'inviting an accepted friend creates an actionable inbox entry',
    () async {
      final firestore = FakeFirebaseFirestore();
      final parties = PartyService(firestore: firestore);
      final invites = PartyInviteService(firestore: firestore);
      final party = await parties.createParty(
        uid: 'alice',
        name: 'Weekend Walk',
      );
      await firestore.collection('friendships').doc('alice_bob').set({
        'pairKey': 'alice_bob',
        'memberIds': ['alice', 'bob'],
        'createdAt': DateTime.now().toIso8601String(),
        'acceptedRequestId': 'alice_bob',
      });
      await firestore.collection('public_profiles').doc('bob').set({
        'uid': 'bob',
        'username': 'bob',
        'displayName': 'Bob',
      });

      final friends = await invites.getFriends('alice');
      expect(friends.map((friend) => friend.displayName), ['Bob']);
      await invites.invite(party: party, senderId: 'alice', recipientId: 'bob');
      final notification = await firestore
          .collection('profiles')
          .doc('bob')
          .collection('notifications')
          .doc(
            PartyInviteService.notificationId(
              partyId: party.id,
              senderId: 'alice',
            ),
          )
          .get();
      expect(notification.data()?['type'], 'partyInvite');
      expect(notification.data()?['partyId'], party.id);
      final invitedParty = await parties.getParty(
        notification.data()!['partyId'] as String,
      );
      final joined = await parties.joinParty(
        code: invitedParty!.joinCode,
        uid: 'bob',
      );
      expect(joined.isMember('bob'), isTrue);
    },
  );

  test('only a current party member can invite an accepted friend', () async {
    final firestore = FakeFirebaseFirestore();
    final parties = PartyService(firestore: firestore);
    final invites = PartyInviteService(firestore: firestore);
    final party = await parties.createParty(uid: 'alice');
    await expectLater(
      invites.invite(party: party, senderId: 'alice', recipientId: 'bob'),
      throwsStateError,
    );
    await firestore
        .collection('friendships')
        .doc(FriendshipService.pairKeyFor('alice', 'bob'))
        .set({
          'memberIds': ['alice', 'bob'],
        });
    await expectLater(
      invites.invite(party: party, senderId: 'mallory', recipientId: 'bob'),
      throwsStateError,
    );
  });

  test('people in Following appear and can receive an invitation', () async {
    final firestore = FakeFirebaseFirestore();
    final parties = PartyService(firestore: firestore);
    final invites = PartyInviteService(firestore: firestore);
    final party = await parties.createParty(uid: 'alice');
    await firestore.collection('follows').doc('alice_bob').set({
      'followerId': 'alice',
      'followeeId': 'bob',
      'createdAt': DateTime.now().toIso8601String(),
    });
    await firestore.collection('public_profiles').doc('bob').set({
      'uid': 'bob',
      'username': 'bob',
      'displayName': 'Bob',
    });

    expect((await invites.getFriends('alice')).map((friend) => friend.uid), [
      'bob',
    ]);
    await invites.invite(party: party, senderId: 'alice', recipientId: 'bob');
    final notification = await firestore
        .collection('profiles')
        .doc('bob')
        .collection('notifications')
        .get();
    expect(notification.docs.single.data()['type'], 'partyInvite');
  });

  test('an already-partied connection is unavailable for invitation', () async {
    final firestore = FakeFirebaseFirestore();
    final parties = PartyService(firestore: firestore);
    final invites = PartyInviteService(firestore: firestore);
    final party = await parties.createParty(uid: 'alice');
    await parties.createParty(uid: 'bob');
    await firestore.collection('follows').doc('alice_bob').set({
      'followerId': 'alice',
      'followeeId': 'bob',
    });
    await firestore.collection('public_profiles').doc('bob').set({
      'uid': 'bob',
      'username': 'bob',
      'displayName': 'Bob',
    });

    final candidates = await invites.getCandidates('alice');
    expect(candidates.single.profile.displayName, 'Bob');
    expect(candidates.single.isInParty, isTrue);
    await expectLater(
      invites.invite(party: party, senderId: 'alice', recipientId: 'bob'),
      throwsStateError,
    );
    expect(
      (await firestore
              .collection('profiles')
              .doc('bob')
              .collection('notifications')
              .get())
          .docs,
      isEmpty,
    );
  });
}
