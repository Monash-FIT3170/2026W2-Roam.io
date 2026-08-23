/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Comment model for activity_feed social comments under
 *   activities/{activityId}/comments/{commentId}. Replies use parentCommentId
 *   for one reply level beneath a top-level activity comment.
 */

import 'package:cloud_firestore/cloud_firestore.dart';

/// A single comment on a persisted activity.
class ActivityComment {
  const ActivityComment({
    required this.id,
    required this.activityId,
    required this.authorId,
    required this.authorDisplayName,
    required this.text,
    required this.createdAt,
    this.updatedAt,
    this.parentCommentId,
    this.replyToUserId,
    this.replyToDisplayName,
    this.authorUsername,
    this.authorPhotoUrl,
  });

  final String id;
  final String activityId;
  final String authorId;
  final String authorDisplayName;
  final String? authorUsername;
  final String? authorPhotoUrl;
  final String text;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? parentCommentId;
  final String? replyToUserId;
  final String? replyToDisplayName;

  bool get isReply => parentCommentId != null && parentCommentId!.isNotEmpty;

  factory ActivityComment.fromMap(
    String id,
    String activityId,
    Map<String, dynamic> data,
  ) {
    return ActivityComment(
      id: id,
      activityId: activityId,
      authorId: _readString(data['authorId']) ?? '',
      authorDisplayName: _readString(data['authorDisplayName']) ?? 'Traveller',
      authorUsername: _readString(data['authorUsername']),
      authorPhotoUrl: _readString(data['authorPhotoUrl']),
      text: _readString(data['text']) ?? '',
      createdAt: _parseCreatedAt(data['createdAt']),
      updatedAt: _parseOptionalDate(data['updatedAt']),
      parentCommentId: _readString(data['parentCommentId']),
      replyToUserId: _readString(data['replyToUserId']),
      replyToDisplayName: _readString(data['replyToDisplayName']),
    );
  }
}

String? _readString(Object? raw) {
  if (raw == null) return null;
  if (raw is String) return raw;
  return raw.toString();
}

DateTime _parseCreatedAt(Object? raw) {
  return _parseOptionalDate(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _parseOptionalDate(Object? raw) {
  if (raw is Timestamp) {
    return raw.toDate();
  }
  if (raw is DateTime) {
    return raw;
  }
  if (raw is String) {
    return DateTime.tryParse(raw);
  }
  if (raw is int) {
    return DateTime.fromMillisecondsSinceEpoch(raw);
  }
  return null;
}

/// Formats a comment count with correct singular/plural labelling.
String formatCommentCount(int count) {
  if (count == 1) {
    return '1 comment';
  }
  return '$count comments';
}
