/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Owns public profile search (usernameSearch / displayNameSearch prefix),
 *   friend request transactions, friendship state, and reactive streams
 *   consumed by Social and in-app notifications. Search only reads
 *   public_profiles (needs signed-in list/read rules deployed) and is
 *   independent of Follow state.
 */

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/friend_relationship.dart';
import '../domain/friend_request.dart';
import '../domain/friendship.dart';
import '../domain/public_profile.dart';

/// Firestore-backed service for social search and friend relationships.
class FriendshipService {
  FriendshipService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String publicProfilesCollection = 'public_profiles';
  static const String friendRequestsCollection = 'friend_requests';
  static const String friendshipsCollection = 'friendships';

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _publicProfiles =>
      _firestore.collection(publicProfilesCollection);

  CollectionReference<Map<String, dynamic>> get _friendRequests =>
      _firestore.collection(friendRequestsCollection);

  CollectionReference<Map<String, dynamic>> get _friendships =>
      _firestore.collection(friendshipsCollection);

  /// Deterministic ID shared by the two users' request and friendship state.
  static String pairKeyFor(String userA, String userB) {
    final ids = [userA, userB]..sort();
    return ids.join('_');
  }

  /// Searches public profiles by normalized display-name or username prefix.
  Future<List<PublicProfile>> searchUsers({
    required String query,
    required String currentUserId,
    int limit = 20,
  }) async {
    final displayNameQuery = normalizeSearchText(query);
    final usernameQuery = normalizeUsernameSearchText(query);
    if (displayNameQuery.isEmpty && usernameQuery.isEmpty) {
      return const <PublicProfile>[];
    }

    final displayNameResults = await _searchPublicProfilesByField(
      field: 'displayNameSearch',
      normalizedQuery: displayNameQuery,
      limit: limit,
    );
    final usernameResults = await _searchPublicProfilesByField(
      field: 'usernameSearch',
      normalizedQuery: usernameQuery,
      limit: limit,
    );

    final byUid = <String, PublicProfile>{};
    for (final profile in [...displayNameResults, ...usernameResults]) {
      if (profile.uid == currentUserId) continue;
      byUid.putIfAbsent(profile.uid, () => profile);
    }

    final results = byUid.values.toList()
      ..sort((a, b) {
        final byName = a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
        if (byName != 0) return byName;
        return a.username.toLowerCase().compareTo(b.username.toLowerCase());
      });

    return results.take(limit).toList();
  }

  Future<List<PublicProfile>> _searchPublicProfilesByField({
    required String field,
    required String normalizedQuery,
    required int limit,
  }) async {
    if (normalizedQuery.isEmpty) return const <PublicProfile>[];

    try {
      final snapshot = await _publicProfiles
          .orderBy(field)
          .startAt([normalizedQuery])
          .endAt(['$normalizedQuery\uf8ff'])
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => PublicProfile.fromMap(doc.data()))
          .where((profile) => profile.uid.isNotEmpty)
          .toList();
    } on FirebaseException catch (error) {
      // Preserve the field name so Find People logs can report which query failed.
      throw FirebaseException(
        plugin: error.plugin,
        code: error.code,
        message:
            'public_profiles orderBy($field) prefix "$normalizedQuery": '
            '${error.message}',
      );
    }
  }

  /// Reads a public profile by uid for notification copy.
  Future<PublicProfile?> getPublicProfile(String uid) async {
    final doc = await _publicProfiles.doc(uid).get();
    final data = doc.data();
    if (data == null) return null;
    return PublicProfile.fromMap(data);
  }

  /// Watches a public profile by uid for reactive external profile screens.
  Stream<PublicProfile?> watchPublicProfile(String uid) {
    return _publicProfiles.doc(uid).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return PublicProfile.fromMap(data);
    });
  }

  /// Creates or refreshes the public search profile mirror.
  Future<void> upsertPublicProfile({
    required String uid,
    required String username,
    required String displayName,
    String? photoUrl,
    DateTime? createdAt,
    int? xp,
    int? level,
    bool isPrivateAccount = false,
  }) {
    final now = DateTime.now();
    return _publicProfiles
        .doc(uid)
        .set(
          PublicProfile(
            uid: uid,
            username: username,
            displayName: displayName,
            photoUrl: photoUrl,
            xp: xp,
            level: level,
            isPrivateAccount: isPrivateAccount,
          ).toMap(createdAt: createdAt ?? now, updatedAt: now),
          SetOptions(merge: true),
        );
  }

  /// Sends a pending request unless the pair already has actionable state.
  Future<SendFriendRequestResult> sendRequest({
    required String senderId,
    required String recipientId,
  }) async {
    if (senderId == recipientId) {
      return SendFriendRequestResult.selfRequest;
    }

    final pairKey = pairKeyFor(senderId, recipientId);
    final requestRef = _friendRequests.doc(pairKey);
    final friendshipRef = _friendships.doc(pairKey);
    final now = DateTime.now();

    return _firestore.runTransaction<SendFriendRequestResult>((
      transaction,
    ) async {
      final friendshipDoc = await transaction.get(friendshipRef);
      if (friendshipDoc.exists) {
        return SendFriendRequestResult.alreadyFriends;
      }

      final requestDoc = await transaction.get(requestRef);
      final requestData = requestDoc.data();
      if (requestData != null) {
        final request = FriendRequest.fromMap(requestDoc.id, requestData);
        if (request.status == FriendRequestStatus.pending) {
          if (request.senderId == senderId) {
            return SendFriendRequestResult.alreadySent;
          }
          return SendFriendRequestResult.incomingRequest;
        }
      }

      final request = FriendRequest(
        id: pairKey,
        pairKey: pairKey,
        senderId: senderId,
        recipientId: recipientId,
        status: FriendRequestStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      transaction.set(requestRef, request.toMap());
      return SendFriendRequestResult.sent;
    });
  }

  /// Accepts a pending request addressed to [currentUserId].
  Future<void> acceptRequest({
    required String requestId,
    required String currentUserId,
  }) async {
    final requestRef = _friendRequests.doc(requestId);
    final now = DateTime.now();

    await _firestore.runTransaction<void>((transaction) async {
      final requestDoc = await transaction.get(requestRef);
      final data = requestDoc.data();
      if (data == null) {
        throw StateError('Friend request no longer exists.');
      }

      final request = FriendRequest.fromMap(requestDoc.id, data);
      if (request.recipientId != currentUserId) {
        throw StateError('Only the recipient can accept this request.');
      }
      if (request.status != FriendRequestStatus.pending) {
        throw StateError('Friend request is no longer pending.');
      }

      final pairKey = request.pairKey;
      final friendship = Friendship(
        pairKey: pairKey,
        memberIds: [request.senderId, request.recipientId]..sort(),
        createdAt: now,
        acceptedRequestId: request.id,
      );

      transaction.update(requestRef, <String, dynamic>{
        'status': FriendRequestStatus.accepted.wireValue,
        'updatedAt': now.toIso8601String(),
      });
      transaction.set(_friendships.doc(pairKey), friendship.toMap());
    });
  }

  /// Declines a pending request addressed to [currentUserId].
  Future<void> declineRequest({
    required String requestId,
    required String currentUserId,
  }) async {
    final requestRef = _friendRequests.doc(requestId);
    final now = DateTime.now();

    await _firestore.runTransaction<void>((transaction) async {
      final requestDoc = await transaction.get(requestRef);
      final data = requestDoc.data();
      if (data == null) {
        throw StateError('Friend request no longer exists.');
      }

      final request = FriendRequest.fromMap(requestDoc.id, data);
      if (request.recipientId != currentUserId) {
        throw StateError('Only the recipient can decline this request.');
      }
      if (request.status != FriendRequestStatus.pending) {
        throw StateError('Friend request is no longer pending.');
      }

      transaction.update(requestRef, <String, dynamic>{
        'status': FriendRequestStatus.declined.wireValue,
        'updatedAt': now.toIso8601String(),
      });
    });
  }

  /// Streams the relationship between [currentUserId] and [otherUserId].
  Stream<FriendRelationship> watchRelationship({
    required String currentUserId,
    required String otherUserId,
  }) {
    if (currentUserId == otherUserId) {
      return Stream<FriendRelationship>.value(const FriendRelationship.none());
    }

    final pairKey = pairKeyFor(currentUserId, otherUserId);
    late StreamController<FriendRelationship> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? friendshipSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? requestSub;
    var isFriend = false;
    FriendRequest? request;

    void emit() {
      if (controller.isClosed) return;
      if (isFriend) {
        controller.add(
          FriendRelationship(
            status: FriendRelationshipStatus.friends,
            request: request,
          ),
        );
        return;
      }
      if (request != null && request!.status == FriendRequestStatus.pending) {
        controller.add(
          FriendRelationship(
            status: request!.senderId == currentUserId
                ? FriendRelationshipStatus.requestSent
                : FriendRelationshipStatus.incomingRequest,
            request: request,
          ),
        );
        return;
      }
      controller.add(const FriendRelationship.none());
    }

    controller = StreamController<FriendRelationship>.broadcast(
      onListen: () {
        friendshipSub = _friendships.doc(pairKey).snapshots().listen((doc) {
          isFriend = doc.exists;
          emit();
        }, onError: controller.addError);
        requestSub = _friendRequests.doc(pairKey).snapshots().listen((doc) {
          final data = doc.data();
          request = data == null ? null : FriendRequest.fromMap(doc.id, data);
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await friendshipSub?.cancel();
        await requestSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Streams pending requests addressed to [currentUserId].
  Stream<List<FriendRequest>> watchIncomingRequests(String currentUserId) {
    return _friendRequests
        .where('recipientId', isEqualTo: currentUserId)
        .where('status', isEqualTo: FriendRequestStatus.pending.wireValue)
        .snapshots()
        .map(_requestsFromSnapshot);
  }

  /// Streams accepted requests originally sent by [currentUserId].
  Stream<List<FriendRequest>> watchAcceptedRequestsForSender(
    String currentUserId,
  ) {
    return _friendRequests
        .where('senderId', isEqualTo: currentUserId)
        .where('status', isEqualTo: FriendRequestStatus.accepted.wireValue)
        .snapshots()
        .map(_requestsFromSnapshot);
  }

  List<FriendRequest> _requestsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final requests =
        snapshot.docs
            .map((doc) => FriendRequest.fromMap(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return requests;
  }
}
