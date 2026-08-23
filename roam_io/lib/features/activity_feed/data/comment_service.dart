/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Firestore comments for activities at activities/{activityId}/comments.
 *   Exposes live comment/reply lists, total conversation counts, and
 *   persistent social inbox notifications for activity comments.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../social/domain/social_notification.dart';
import '../models/activity_comment.dart';

/// Persists and watches comments under an activity document.
class CommentService {
  CommentService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _comments(String activityId) {
    return _firestore
        .collection('activities')
        .doc(activityId)
        .collection('comments');
  }

  /// Live comments and replies for [activityId], oldest first for threading.
  Stream<List<ActivityComment>> watchComments(String activityId) {
    debugPrint('[CommentService] watchComments activityId=$activityId');
    return _comments(activityId).orderBy('createdAt').snapshots().map((
      snapshot,
    ) {
      final comments = <ActivityComment>[];
      for (final doc in snapshot.docs) {
        try {
          comments.add(ActivityComment.fromMap(doc.id, activityId, doc.data()));
        } catch (error, stackTrace) {
          debugPrint(
            '[CommentService] skip unreadable comment '
            'activityId=$activityId commentId=${doc.id} error=$error\n$stackTrace',
          );
        }
      }
      return comments;
    });
  }

  /// Live total conversation count for activity cards.
  Stream<int> watchCommentCount(String activityId) {
    debugPrint('[CommentService] watchCommentCount activityId=$activityId');
    return _comments(activityId).snapshots().map((snapshot) => snapshot.size);
  }

  /// Creates a comment. [text] must already be trimmed and non-empty.
  Future<ActivityComment> addComment({
    required String activityId,
    required String authorId,
    required String authorDisplayName,
    required String text,
    required String activityOwnerId,
    String? authorUsername,
    String? authorPhotoUrl,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Comment text must be non-empty');
    }

    final resolvedOwnerId = await _resolveActivityOwnerId(
      activityId: activityId,
      fallbackOwnerId: activityOwnerId,
    );
    debugPrint(
      '[CommentService] addComment activityId=$activityId '
      'ownerId=$resolvedOwnerId authorId=$authorId',
    );

    final createdAt = DateTime.now();
    final doc = _comments(activityId).doc();
    final comment = ActivityComment(
      id: doc.id,
      activityId: activityId,
      authorId: authorId,
      authorDisplayName: authorDisplayName,
      authorUsername: authorUsername,
      authorPhotoUrl: authorPhotoUrl,
      text: trimmed,
      createdAt: createdAt,
    );

    await doc.set(
      _commentMap(
        activityId: activityId,
        authorId: authorId,
        authorDisplayName: authorDisplayName,
        authorUsername: authorUsername,
        authorPhotoUrl: authorPhotoUrl,
        text: trimmed,
        createdAt: createdAt,
        parentCommentId: null,
      ),
    );

    if (authorId != resolvedOwnerId) {
      await _tryCreateNotification(
        SocialNotification(
          id: SocialNotification.activityCommentNotificationIdFor(
            activityId: activityId,
            commentId: doc.id,
          ),
          recipientId: resolvedOwnerId,
          actorId: authorId,
          type: SocialNotificationType.activityComment,
          createdAt: createdAt,
          activityId: activityId,
          commentId: doc.id,
        ),
      );
    }

    return comment;
  }

  Future<ActivityComment> replyToComment({
    required String activityId,
    required String activityOwnerId,
    required ActivityComment parentComment,
    required String authorId,
    required String authorDisplayName,
    required String text,
    String? authorUsername,
    String? authorPhotoUrl,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Reply text must be non-empty');
    }

    final resolvedOwnerId = await _resolveActivityOwnerId(
      activityId: activityId,
      fallbackOwnerId: activityOwnerId,
    );
    debugPrint(
      '[CommentService] replyToComment activityId=$activityId '
      'ownerId=$resolvedOwnerId authorId=$authorId '
      'parentCommentId=${parentComment.id}',
    );

    final parentId = parentComment.isReply
        ? parentComment.parentCommentId!
        : parentComment.id;
    final createdAt = DateTime.now();
    final doc = _comments(activityId).doc();
    final reply = ActivityComment(
      id: doc.id,
      activityId: activityId,
      authorId: authorId,
      authorDisplayName: authorDisplayName,
      authorUsername: authorUsername,
      authorPhotoUrl: authorPhotoUrl,
      text: trimmed,
      createdAt: createdAt,
      updatedAt: createdAt,
      parentCommentId: parentId,
      replyToUserId: parentComment.authorId,
      replyToDisplayName: parentComment.authorDisplayName,
    );

    await doc.set(
      _commentMap(
        activityId: activityId,
        authorId: authorId,
        authorDisplayName: authorDisplayName,
        authorUsername: authorUsername,
        authorPhotoUrl: authorPhotoUrl,
        text: trimmed,
        createdAt: createdAt,
        parentCommentId: parentId,
        replyToUserId: parentComment.authorId,
        replyToDisplayName: parentComment.authorDisplayName,
      ),
    );

    if (authorId != parentComment.authorId) {
      await _tryCreateNotification(
        SocialNotification(
          id: SocialNotification.commentReplyNotificationIdFor(
            activityId: activityId,
            replyId: doc.id,
            recipientId: parentComment.authorId,
          ),
          recipientId: parentComment.authorId,
          actorId: authorId,
          type: SocialNotificationType.commentReply,
          createdAt: createdAt,
          activityId: activityId,
          commentId: doc.id,
        ),
      );
    }

    if (resolvedOwnerId != authorId &&
        resolvedOwnerId != parentComment.authorId) {
      await _tryCreateNotification(
        SocialNotification(
          id: SocialNotification.activityReplyNotificationIdFor(
            activityId: activityId,
            replyId: doc.id,
            ownerId: resolvedOwnerId,
          ),
          recipientId: resolvedOwnerId,
          actorId: authorId,
          type: SocialNotificationType.activityComment,
          createdAt: createdAt,
          activityId: activityId,
          commentId: doc.id,
        ),
      );
    }

    return reply;
  }

  Future<String> _resolveActivityOwnerId({
    required String activityId,
    required String fallbackOwnerId,
  }) async {
    try {
      final doc = await _firestore
          .collection('activities')
          .doc(activityId)
          .get();
      if (!doc.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Cannot comment because activities/$activityId is missing.',
        );
      }
      final data = doc.data();
      if (data == null) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Cannot comment because activities/$activityId has no data.',
        );
      }
      final ownerId = data['ownerId'];
      if (ownerId is String && ownerId.isNotEmpty) return ownerId;
      final profileId = data['profileId'];
      if (profileId is String && profileId.isNotEmpty) return profileId;
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'failed-precondition',
        message:
            'Cannot comment because activities/$activityId has no ownerId.',
      );
    } catch (error) {
      debugPrint(
        '[CommentService] owner resolve failed activityId=$activityId '
        'error=$error',
      );
      if (error is FirebaseException) rethrow;
    }
    return fallbackOwnerId;
  }

  Future<void> _tryCreateNotification(SocialNotification notification) async {
    try {
      await _firestore
          .collection('profiles')
          .doc(notification.recipientId)
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toMap(), SetOptions(merge: true));
    } catch (error) {
      final code = error is FirebaseException ? error.code : 'unknown';
      debugPrint(
        '[CommentService] notification write failed id=${notification.id} '
        'type=${notification.type.name} recipientId=${notification.recipientId} '
        'actorId=${notification.actorId} code=$code error=$error',
      );
    }
  }
}

Map<String, dynamic> _commentMap({
  required String activityId,
  required String authorId,
  required String authorDisplayName,
  required String text,
  required DateTime createdAt,
  required String? parentCommentId,
  String? authorUsername,
  String? authorPhotoUrl,
  String? replyToUserId,
  String? replyToDisplayName,
}) {
  return <String, dynamic>{
    'activityId': activityId,
    'authorId': authorId,
    'authorDisplayName': authorDisplayName,
    'authorUsername': authorUsername,
    'authorPhotoUrl': authorPhotoUrl,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': createdAt.toIso8601String(),
    'parentCommentId': parentCommentId,
    'replyToUserId': replyToUserId,
    'replyToDisplayName': replyToDisplayName,
  };
}
