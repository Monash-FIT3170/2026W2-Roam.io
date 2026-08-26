/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Activity comment Like persistence under
 *   activities/{activityId}/comments/{commentId}/likes/{userId}.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../social/domain/social_notification.dart';

class CommentLikeService {
  CommentLikeService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _likes({
    required String activityId,
    required String commentId,
  }) {
    return _firestore
        .collection('activities')
        .doc(activityId)
        .collection('comments')
        .doc(commentId)
        .collection('likes');
  }

  Stream<bool> watchIsLiked({
    required String activityId,
    required String commentId,
    required String userId,
  }) {
    return _likes(
      activityId: activityId,
      commentId: commentId,
    ).doc(userId).snapshots().map((doc) => doc.exists);
  }

  Stream<int> watchLikeCount({
    required String activityId,
    required String commentId,
  }) {
    return _likes(
      activityId: activityId,
      commentId: commentId,
    ).snapshots().map((snapshot) => snapshot.size);
  }

  Future<void> toggleLike({
    required String activityId,
    required String commentId,
    required String commentAuthorId,
    required String userId,
  }) async {
    final ref = _likes(
      activityId: activityId,
      commentId: commentId,
    ).doc(userId);
    DateTime? createdAt;
    await _firestore.runTransaction<void>((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists) {
        transaction.delete(ref);
        return;
      }
      final now = DateTime.now();
      createdAt = now;
      transaction.set(ref, <String, dynamic>{
        'activityId': activityId,
        'commentId': commentId,
        'commentAuthorId': commentAuthorId,
        'userId': userId,
        'createdAt': now.toIso8601String(),
      });
    });

    final notificationCreatedAt = createdAt;
    if (notificationCreatedAt != null && userId != commentAuthorId) {
      await _tryCreateLikeNotification(
        activityId: activityId,
        commentId: commentId,
        recipientId: commentAuthorId,
        actorId: userId,
        createdAt: notificationCreatedAt,
      );
    }
  }

  Future<void> _tryCreateLikeNotification({
    required String activityId,
    required String commentId,
    required String recipientId,
    required String actorId,
    required DateTime createdAt,
  }) async {
    final notification = SocialNotification(
      id: SocialNotification.commentLikeNotificationIdFor(
        activityId: activityId,
        commentId: commentId,
        actorId: actorId,
      ),
      recipientId: recipientId,
      actorId: actorId,
      type: SocialNotificationType.commentLike,
      createdAt: createdAt,
      activityId: activityId,
      commentId: commentId,
    );
    try {
      await _firestore
          .collection('profiles')
          .doc(recipientId)
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toMap(), SetOptions(merge: true));
    } catch (error) {
      final code = error is FirebaseException ? error.code : 'unknown';
      debugPrint(
        '[CommentLikeService] notification write failed activityId=$activityId '
        'commentId=$commentId recipientId=$recipientId actorId=$actorId '
        'code=$code error=$error',
      );
    }
  }
}
