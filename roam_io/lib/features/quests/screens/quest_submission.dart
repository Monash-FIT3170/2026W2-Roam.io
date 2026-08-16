/*
 * Description:
 *   Represents evidence submitted by a user when attempting to complete
 *   a quest.
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

  final String? photoUrl;
}