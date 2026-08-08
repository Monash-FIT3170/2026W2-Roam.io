/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Persistent social inbox notification for public-profile Follow events.
 *   Stored at profiles/{recipientId}/notifications/{id} where id matches the
 *   follows/{followerId_followeeId} document for dedupe.
 */

/// Social inbox notification types currently supported.
enum SocialNotificationType { follow }

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
