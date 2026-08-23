/*
 * Description:
 *   Represents evidence collected from the user when attempting to
 *   complete a quest.
 */

class QuestSubmission {
  const QuestSubmission({
    required this.questId,
    this.latitude,
    this.longitude,
    this.photoUrl,
  });

  final String questId;

  final double? latitude;
  final double? longitude;

  /// Optional retained Storage URL.
  /// AI verification itself uses the local image bytes before upload.
  final String? photoUrl;
}
