import 'package:cloud_firestore/cloud_firestore.dart';

import '../../social/data/friendship_service.dart';
import '../../social/domain/public_profile.dart';
import '../domain/party.dart';
import 'party_service.dart';

class PartyInviteCandidate {
  const PartyInviteCandidate({required this.profile, required this.isInParty});

  final PublicProfile profile;
  final bool isInParty;
}

/// Sends a party invitation to an accepted friend through their social inbox.
class PartyInviteService {
  PartyInviteService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<PublicProfile>> getFriends(String uid) async {
    final results = await Future.wait([
      _firestore
          .collection(FriendshipService.friendshipsCollection)
          .where('memberIds', arrayContains: uid)
          .get(),
      _firestore
          .collection('follows')
          .where('followerId', isEqualTo: uid)
          .get(),
    ]);
    final pairs = results[0];
    final following = results[1];
    final ids = <String>{};
    for (final pair in pairs.docs) {
      ids.addAll((pair.data()['memberIds'] as List<dynamic>).cast<String>());
    }
    for (final follow in following.docs) {
      final target = follow.data()['followeeId'] as String?;
      if (target != null && target.isNotEmpty) ids.add(target);
    }
    ids.remove(uid);
    final profiles = await Future.wait(
      ids.map((id) => _firestore.collection('public_profiles').doc(id).get()),
    );
    return profiles
        .where((doc) => doc.data() != null)
        .map((doc) => PublicProfile.fromMap(doc.data()!))
        .toList()
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
  }

  Future<List<PartyInviteCandidate>> getCandidates(String uid) async {
    final friends = await getFriends(uid);
    final parties = PartyService(firestore: _firestore);
    return Future.wait(
      friends.map((profile) async {
        final memberships = await parties.getUserParties(profile.uid);
        return PartyInviteCandidate(
          profile: profile,
          isInParty: memberships.isNotEmpty,
        );
      }),
    );
  }

  static String notificationId({
    required String partyId,
    required String senderId,
  }) => 'party_invite_${partyId}_$senderId';

  Future<void> invite({
    required Party party,
    required String senderId,
    required String recipientId,
  }) async {
    if (senderId == recipientId || !party.isMember(senderId)) {
      throw StateError('Only a party member can invite a friend.');
    }
    if (party.isMember(recipientId)) {
      throw StateError('This friend is already in the party.');
    }
    if ((await PartyService(
      firestore: _firestore,
    ).getUserParties(recipientId)).isNotEmpty) {
      throw StateError('This friend is already in another party.');
    }
    final pairKey = FriendshipService.pairKeyFor(senderId, recipientId);
    final pairRef = _firestore.collection('friendships').doc(pairKey);
    final followRef = _firestore
        .collection('follows')
        .doc('${senderId}_$recipientId');
    final partyRef = _firestore.collection('parties').doc(party.id);
    final notificationRef = _firestore
        .collection('profiles')
        .doc(recipientId)
        .collection('notifications')
        .doc(notificationId(partyId: party.id, senderId: senderId));
    await _firestore.runTransaction((transaction) async {
      final follow = await transaction.get(followRef);
      // A followed user need not have a friendship document. Firestore only
      // lets participants read that collection, including individual gets.
      final pair = follow.exists ? null : await transaction.get(pairRef);
      final liveParty = await transaction.get(partyRef);
      final liveData = liveParty.data();
      if ((!follow.exists && pair?.exists != true) || liveData == null) {
        throw StateError('The connection or party is no longer available.');
      }
      final currentParty = Party.fromMap(liveParty.id, liveData);
      if (!currentParty.isMember(senderId) ||
          currentParty.isMember(recipientId)) {
        throw StateError('This invitation is no longer available.');
      }
      transaction.set(notificationRef, {
        'recipientId': recipientId,
        'actorId': senderId,
        'type': 'partyInvite',
        'partyId': party.id,
        'createdAt': DateTime.now().toIso8601String(),
        'readAt': null,
      });
    });
  }
}
