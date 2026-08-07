/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Firestore-backed one-way follow actions and reactive follow counts.
 *   Documents live at follows/{followerId_followeeId} with followerId,
 *   followeeId, and createdAt. Counts are derived from relationship queries
 *   (Following = followerId == uid, Followers = followeeId == uid), independent
 *   of mutual friendship.
 */

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/follow.dart';

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

  /// Counts users followed by [uid].
  Stream<int> watchFollowingCount(String uid) {
    return _follows
        .where('followerId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  /// Counts users following [uid].
  Stream<int> watchFollowerCount(String uid) {
    return _follows
        .where('followeeId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.size);
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
  }

  /// Removes a one-way follow. No-ops for self-follow attempts.
  Future<void> unfollow({
    required String followerId,
    required String followeeId,
  }) async {
    if (followerId == followeeId) return;
    await _follows.doc(followIdFor(followerId, followeeId)).delete();
  }
}
