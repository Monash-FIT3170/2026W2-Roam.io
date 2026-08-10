/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Persistent social inbox notifications for public follows, private follow
 *   requests, request acceptance, and activity interactions.
 *   Stored at profiles/{recipientId}/notifications/{id}. Recipient follow and
 *   request rows represent current relationship state, not history.
 */

/// Social inbox notification types currently supported.
enum SocialNotificationType {
  follow,
  followRequest,
  followRequestAccepted,
  activityKudos,
  activityComment,
  commentReply,
  commentLike,
}

/// One persisted social notification row for a recipient.
class SocialNotification {
  const SocialNotification({
    required this.id,
    required this.recipientId,
    required this.actorId,
    required this.type,
    required this.createdAt,
    this.readAt,
    this.activityId,
    this.commentId,
  });

  final String id;
  final String recipientId;
  final String actorId;
  final SocialNotificationType type;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? activityId;
  final String? commentId;

  bool get isRead => readAt != null;
  bool get isFollow => type == SocialNotificationType.follow;
  bool get isFollowRequest => type == SocialNotificationType.followRequest;
  bool get isFollowRequestAccepted =>
      type == SocialNotificationType.followRequestAccepted;
  bool get isActivityInteraction =>
      type == SocialNotificationType.activityKudos ||
      type == SocialNotificationType.activityComment ||
      type == SocialNotificationType.commentReply ||
      type == SocialNotificationType.commentLike;
  bool get isActivityReplyOnOwnedActivity =>
      type == SocialNotificationType.activityComment &&
      id.startsWith('activity_reply_');

  static String followNotificationIdFor({
    required String followerId,
    required String followeeId,
  }) {
    return 'follow_${followerId}_$followeeId';
  }

  static String activityKudosNotificationIdFor({
    required String activityId,
    required String actorId,
  }) {
    return 'activity_kudos_${_safeId(activityId)}_$actorId';
  }

  static String activityCommentNotificationIdFor({
    required String activityId,
    required String commentId,
  }) {
    return 'activity_comment_${_safeId(activityId)}_$commentId';
  }

  static String commentReplyNotificationIdFor({
    required String activityId,
    required String replyId,
    required String recipientId,
  }) {
    return 'comment_reply_${_safeId(activityId)}_${replyId}_$recipientId';
  }

  static String activityReplyNotificationIdFor({
    required String activityId,
    required String replyId,
    required String ownerId,
  }) {
    return 'activity_reply_${_safeId(activityId)}_${replyId}_$ownerId';
  }

  static String commentLikeNotificationIdFor({
    required String activityId,
    required String commentId,
    required String actorId,
  }) {
    return 'comment_like_${_safeId(activityId)}_${commentId}_$actorId';
  }

  factory SocialNotification.fromMap(String id, Map<String, dynamic> data) {
    return SocialNotification(
      id: id,
      recipientId: data['recipientId'] as String? ?? '',
      actorId: data['actorId'] as String? ?? '',
      type: _typeFromString(data['type'] as String?),
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      readAt: _parseDate(data['readAt']),
      activityId: data['activityId'] as String?,
      commentId: data['commentId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'recipientId': recipientId,
      'actorId': actorId,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      if (activityId != null) 'activityId': activityId,
      if (commentId != null) 'commentId': commentId,
    };
  }

  static SocialNotificationType _typeFromString(String? raw) {
    return switch (raw) {
      'follow' => SocialNotificationType.follow,
      'followRequest' => SocialNotificationType.followRequest,
      'followRequestAccepted' => SocialNotificationType.followRequestAccepted,
      'activityKudos' => SocialNotificationType.activityKudos,
      'activityComment' => SocialNotificationType.activityComment,
      'commentReply' => SocialNotificationType.commentReply,
      'commentLike' => SocialNotificationType.commentLike,
      _ => SocialNotificationType.follow,
    };
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

String _safeId(String value) => value.replaceAll('/', '_');
