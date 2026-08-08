/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Firestore-backed one-way follow actions, reactive follow counts, and
 *   follower/following id list streams. Documents live at
 *   follows/{followerId_followeeId}. After a successful follow write,
 *   best-effort creates profiles/{followeeId}/notifications/{followId}
 *   (Cloud Function is preferred when deployed; same deterministic ID
 *   dedupes both writers). Unfollow is silent — no notification.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/follow.dart';
import '../domain/social_notification.dart';

/// Owns one-way public follow relationships.
class FollowService {
  FollowService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String followsCollection = 'follows';

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _follows =>
      _firestore.collection(followsCollection);

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
    final follow = Follow(
      id: followIdFor(followerId, followeeId),
      followerId: followerId,
      followeeId: followeeId,
      createdAt: DateTime.now(),
    );
    await _follows.doc(follow.id).set(follow.toMap());
    await _tryCreateFollowNotification(follow);
  }

  /// Best-effort inbox write after follow. Failures are logged and ignored so
  /// the Follow relationship remains authoritative.
  Future<void> _tryCreateFollowNotification(Follow follow) async {
    try {
      final notification = SocialNotification(
        id: follow.id,
        recipientId: follow.followeeId,
        actorId: follow.followerId,
        type: SocialNotificationType.follow,
        createdAt: follow.createdAt,
      );
      await _firestore
          .collection('profiles')
          .doc(follow.followeeId)
          .collection('notifications')
          .doc(follow.id)
          .set(notification.toMap(), SetOptions(merge: true));
    } catch (error) {
      final code = error is FirebaseException ? error.code : 'unknown';
      debugPrint(
        '[FollowService] notification write failed '
        'followId=${follow.id} recipientId=${follow.followeeId} '
        'actorId=${follow.followerId} code=$code error=$error',
      );
    }
  }

  /// Removes a one-way follow initiated by the follower. No-ops for self-follow.
  /// Silent: does not create or delete notifications.
  Future<void> unfollow({
    required String followerId,
    required String followeeId,
  }) async {
    if (followerId == followeeId) return;
    await _follows.doc(followIdFor(followerId, followeeId)).delete();
  }

  /// Followee removes [followerId]'s follow (no notification to the follower).
  Future<void> removeFollower({
    required String followerId,
    required String followeeId,
  }) async {
    await unfollow(followerId: followerId, followeeId: followeeId);
  }
}
