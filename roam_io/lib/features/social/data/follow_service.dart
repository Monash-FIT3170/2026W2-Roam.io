/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Firestore-backed one-way follow actions, reactive follow counts, and
 *   follower/following id list streams. Documents live at
 *   follows/{followerId_followeeId}. After a newly created follow write,
 *   best-effort creates one current notification row. Unfollow removes it.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

import '../domain/follow_relationship_state.dart';
import '../domain/follow.dart';
import '../domain/social_notification.dart';
import 'follow_request_service.dart';

/// Owns one-way public follow relationships.
class FollowService {
  FollowService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String followsCollection = 'follows';

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _follows =>
      _firestore.collection(followsCollection);

  CollectionReference<Map<String, dynamic>> get _followRequests =>
      _firestore.collection(FollowRequestService.followRequestsCollection);

  /// Deterministic document ID for "follower follows followee".
  static String followIdFor(String followerId, String followeeId) {
    return '${followerId}_$followeeId';
  }

  /// Watches whether [followerId] currently follows [followeeId].
  Stream<bool> watchIsFollowing({
    required String followerId,
    required String followeeId,
  }) {
    if (followerId == followeeId) {
      return Stream<bool>.value(false);
    }
    return _follows
        .doc(followIdFor(followerId, followeeId))
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Watches the derived Follow / Requested / Following state for a pair.
  Stream<FollowRelationshipState> watchFollowState({
    required String followerId,
    required String followeeId,
  }) {
    if (followerId == followeeId) {
      return Stream<FollowRelationshipState>.value(
        const FollowRelationshipState(
          status: FollowRelationshipStatus.notFollowing,
          isTargetPrivate: false,
        ),
      );
    }

    late StreamController<FollowRelationshipState> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? followSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? requestSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
    publicProfileSub;
    var follows = false;
    var hasPendingRequest = false;
    var isPrivate = false;
    var hasFollow = false;
    var hasRequest = false;
    var hasPrivacy = false;

    void emit() {
      if (controller.isClosed || !hasFollow || !hasRequest || !hasPrivacy) {
        return;
      }
      final status = follows
          ? FollowRelationshipStatus.following
          : (hasPendingRequest && isPrivate
                ? FollowRelationshipStatus.requested
                : FollowRelationshipStatus.notFollowing);
      controller.add(
        FollowRelationshipState(status: status, isTargetPrivate: isPrivate),
      );
    }

    controller = StreamController<FollowRelationshipState>.broadcast(
      onListen: () {
        followSub = _follows
            .doc(followIdFor(followerId, followeeId))
            .snapshots()
            .listen((doc) {
              follows = doc.exists;
              hasFollow = true;
              emit();
            }, onError: controller.addError);
        requestSub = _followRequests
            .doc(FollowRequestService.requestIdFor(followerId, followeeId))
            .snapshots()
            .listen((doc) {
              final data = doc.data();
              hasPendingRequest = data?['status'] == 'pending';
              hasRequest = true;
              emit();
            }, onError: controller.addError);
        publicProfileSub = _firestore
            .collection('public_profiles')
            .doc(followeeId)
            .snapshots()
            .listen((doc) {
              isPrivate = doc.data()?['isPrivateAccount'] as bool? ?? false;
              hasPrivacy = true;
              emit();
            }, onError: controller.addError);
      },
      onCancel: () async {
        await followSub?.cancel();
        await requestSub?.cancel();
        await publicProfileSub?.cancel();
      },
    );
    return controller.stream;
  }

  Query<Map<String, dynamic>> _followingQuery(String uid) {
    return _follows.where('followerId', isEqualTo: uid);
  }

  Query<Map<String, dynamic>> _followersQuery(String uid) {
    return _follows.where('followeeId', isEqualTo: uid);
  }

  /// Counts users followed by [uid].
  Stream<int> watchFollowingCount(String uid) {
    return _followingQuery(uid).snapshots().map((snapshot) => snapshot.size);
  }

  /// Counts users following [uid].
  Stream<int> watchFollowerCount(String uid) {
    return _followersQuery(uid).snapshots().map((snapshot) => snapshot.size);
  }

  /// User ids that [uid] currently follows (same source as following count).
  Stream<List<String>> watchFollowingIds(String uid) {
    return _followingQuery(uid).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => doc.data()['followeeId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false),
    );
  }

  /// User ids that currently follow [uid] (same source as follower count).
  Stream<List<String>> watchFollowerIds(String uid) {
    return _followersQuery(uid).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => doc.data()['followerId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false),
    );
  }

  /// Persists a one-way follow. No-ops for self-follow attempts.
  Future<void> follow({
    required String followerId,
    required String followeeId,
  }) async {
    if (followerId == followeeId) return;
    final followId = followIdFor(followerId, followeeId);
    final followRef = _follows.doc(followId);
    Follow? createdFollow;
    await _firestore.runTransaction<void>((transaction) async {
      final existing = await transaction.get(followRef);
      if (existing.exists) return;
      final follow = Follow(
        id: followId,
        followerId: followerId,
        followeeId: followeeId,
        createdAt: DateTime.now(),
      );
      transaction.set(followRef, follow.toMap());
      createdFollow = follow;
    });
    final follow = createdFollow;
    if (follow != null) {
      await _tryCreateFollowNotification(follow);
    }
  }

  /// Creates an immediate Follow for public targets or a request for private
  /// targets. If a stale request remains after a target becomes public, the
  /// public follow is created and the request is cleaned up best-effort.
  Future<void> followOrRequest({
    required String followerId,
    required String followeeId,
  }) async {
    if (followerId == followeeId) return;
    final publicDoc = await _firestore
        .collection('public_profiles')
        .doc(followeeId)
        .get();
    final targetData = publicDoc.data();
    if (targetData == null) {
      throw StateError('Target profile does not exist.');
    }
    final isPrivate = targetData['isPrivateAccount'] as bool? ?? false;
    final followId = followIdFor(followerId, followeeId);
    final requestId = FollowRequestService.requestIdFor(followerId, followeeId);
    debugPrint(
      '[FollowService] followOrRequest followerId=$followerId '
      'followeeId=$followeeId isPrivateAccount=$isPrivate '
      'followPath=${FollowService.followsCollection}/$followId '
      'requestPath=${FollowRequestService.followRequestsCollection}/$requestId',
    );
    if (isPrivate) {
      await FollowRequestService(
        firestore: _firestore,
      ).sendFollowRequest(requesterId: followerId, targetId: followeeId);
      return;
    }

    await follow(followerId: followerId, followeeId: followeeId);
    await _tryDeleteStaleRequest(
      followerId: followerId,
      followeeId: followeeId,
    );
  }

  /// Best-effort inbox write after follow. Failures are logged and ignored so
  /// the Follow relationship remains authoritative.
  Future<void> _tryCreateFollowNotification(Follow follow) async {
    if (follow.source == FollowRequestService.acceptedFollowSource) {
      return;
    }
    try {
      final notification = SocialNotification(
        id: SocialNotification.followNotificationIdFor(
          followerId: follow.followerId,
          followeeId: follow.followeeId,
        ),
        recipientId: follow.followeeId,
        actorId: follow.followerId,
        type: SocialNotificationType.follow,
        createdAt: follow.createdAt,
      );
      await _firestore
          .collection('profiles')
          .doc(follow.followeeId)
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toMap(), SetOptions(merge: true));
    } catch (error) {
      final code = error is FirebaseException ? error.code : 'unknown';
      debugPrint(
        '[FollowService] notification write failed '
        'followId=${follow.id} notificationId='
        '${SocialNotification.followNotificationIdFor(followerId: follow.followerId, followeeId: follow.followeeId)} '
        'recipientId=${follow.followeeId} '
        'actorId=${follow.followerId} code=$code error=$error',
      );
    }
  }

  /// Removes a one-way follow initiated by the follower. No-ops for self-follow.
  /// Silent: does not create notifications.
  Future<void> unfollow({
    required String followerId,
    required String followeeId,
  }) async {
    if (followerId == followeeId) return;
    await _follows.doc(followIdFor(followerId, followeeId)).delete();
    await _tryDeleteFollowNotification(
      followerId: followerId,
      followeeId: followeeId,
    );
  }

  /// Followee removes [followerId]'s follow (no notification to the follower).
  Future<void> removeFollower({
    required String followerId,
    required String followeeId,
  }) async {
    await unfollow(followerId: followerId, followeeId: followeeId);
  }

  Future<void> cancelFollowRequest({
    required String requesterId,
    required String targetId,
  }) {
    return FollowRequestService(
      firestore: _firestore,
    ).cancelFollowRequest(requesterId: requesterId, targetId: targetId);
  }

  Future<void> _tryDeleteStaleRequest({
    required String followerId,
    required String followeeId,
  }) async {
    try {
      await _followRequests
          .doc(FollowRequestService.requestIdFor(followerId, followeeId))
          .delete();
    } catch (error) {
      final code = error is FirebaseException ? error.code : 'unknown';
      debugPrint(
        '[FollowService] stale request cleanup failed followerId=$followerId '
        'followeeId=$followeeId code=$code error=$error',
      );
    }
  }

  Future<void> _tryDeleteFollowNotification({
    required String followerId,
    required String followeeId,
  }) async {
    final id = SocialNotification.followNotificationIdFor(
      followerId: followerId,
      followeeId: followeeId,
    );
    try {
      await _firestore
          .collection('profiles')
          .doc(followeeId)
          .collection('notifications')
          .doc(id)
          .delete();
    } catch (error) {
      final code = error is FirebaseException ? error.code : 'unknown';
      debugPrint(
        '[FollowService] notification cleanup failed followerId=$followerId '
        'followeeId=$followeeId notificationId=$id code=$code error=$error',
      );
    }
  }
}
