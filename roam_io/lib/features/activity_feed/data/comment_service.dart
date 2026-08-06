/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Firestore comments for activities at activities/{activityId}/comments.
 *   Exposes live comment lists and counts for cards and CommentsScreen.
 *   Notifications for comment creation are intentionally deferred.
 */

import 'package:cloud_firestore/cloud_firestore.dart';

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

  /// Live comments for [activityId], newest first.
  Stream<List<ActivityComment>> watchComments(String activityId) {
    return _comments(
      activityId,
    ).orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ActivityComment.fromMap(doc.id, activityId, doc.data()))
          .toList();
    });
  }

  /// Live comment count for activity cards (same collection as [watchComments]).
  Stream<int> watchCommentCount(String activityId) {
    return _comments(activityId).snapshots().map((snapshot) => snapshot.size);
  }

  /// Creates a comment. [text] must already be trimmed and non-empty.
  Future<ActivityComment> addComment({
    required String activityId,
    required String authorId,
    required String authorDisplayName,
    required String text,
    String? authorUsername,
    String? authorPhotoUrl,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Comment text must be non-empty');
    }

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

    await doc.set(<String, dynamic>{
      'authorId': authorId,
      'authorDisplayName': authorDisplayName,
      'authorUsername': authorUsername,
      'authorPhotoUrl': authorPhotoUrl,
      'text': trimmed,
      'createdAt': createdAt.toIso8601String(),
    });

    return comment;
  }
}
