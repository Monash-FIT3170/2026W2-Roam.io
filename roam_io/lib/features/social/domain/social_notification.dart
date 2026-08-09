/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Persistent social inbox notifications for public follows, private follow
 *   requests, and request acceptance.
 *   Stored at profiles/{recipientId}/notifications/{id}. Recipient follow and
 *   request rows represent current relationship state, not history.
 */

/// Social inbox notification types currently supported.
enum SocialNotificationType { follow, followRequest, followRequestAccepted }

/// One persisted social notification row for a recipient.
class SocialNotification {
  const SocialNotification({
    required this.id,
    required this.recipientId,
    required this.actorId,
    required this.type,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String recipientId;
  final String actorId;
  final SocialNotificationType type;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;
  bool get isFollow => type == SocialNotificationType.follow;
  bool get isFollowRequest => type == SocialNotificationType.followRequest;
  bool get isFollowRequestAccepted =>
      type == SocialNotificationType.followRequestAccepted;

  static String followNotificationIdFor({
    required String followerId,
    required String followeeId,
  }) {
    return 'follow_${followerId}_$followeeId';
  }

  factory SocialNotification.fromMap(String id, Map<String, dynamic> data) {
    return SocialNotification(
      id: id,
      recipientId: data['recipientId'] as String? ?? '',
      actorId: data['actorId'] as String? ?? '',
      type: _typeFromString(data['type'] as String?),
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      readAt: _parseDate(data['readAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'recipientId': recipientId,
      'actorId': actorId,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
    };
  }

  static SocialNotificationType _typeFromString(String? raw) {
    return switch (raw) {
      'follow' => SocialNotificationType.follow,
      'followRequest' => SocialNotificationType.followRequest,
      'followRequestAccepted' => SocialNotificationType.followRequestAccepted,
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
