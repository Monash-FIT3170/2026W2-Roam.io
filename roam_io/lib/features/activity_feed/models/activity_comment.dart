/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Comment model for activity_feed social comments under
 *   activities/{activityId}/comments/{commentId}. Notifications for new
 *   comments are intentionally deferred.
 */

/// A single comment on an activity (personal or friend stub).
class ActivityComment {
  const ActivityComment({
    required this.id,
    required this.activityId,
    required this.authorId,
    required this.authorDisplayName,
    required this.text,
    required this.createdAt,
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

  factory ActivityComment.fromMap(
    String id,
    String activityId,
    Map<String, dynamic> data,
  ) {
    return ActivityComment(
      id: id,
      activityId: activityId,
      authorId: data['authorId'] as String? ?? '',
      authorDisplayName: data['authorDisplayName'] as String? ?? 'Traveller',
      authorUsername: data['authorUsername'] as String?,
      authorPhotoUrl: data['authorPhotoUrl'] as String?,
      text: data['text'] as String? ?? '',
      createdAt:
          DateTime.tryParse(data['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
