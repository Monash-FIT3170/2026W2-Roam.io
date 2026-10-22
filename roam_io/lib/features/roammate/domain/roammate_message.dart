/*
 * Author: Sam Sutherland
 * Last Modified: 06/10/2026
 * Description:
 *   Defines Roammate messages that can be shown as text and spoken aloud.
 */

/// A user-facing Roammate message with display and speech-friendly copy.
class RoammateMessage {
  const RoammateMessage({required this.text, required this.speech});

  /// Text shown inside the application.
  final String text;

  /// Text sent to the text-to-speech engine.
  final String speech;

  /// Message produced when a user unlocks a new map tile.
  factory RoammateMessage.tileUnlocked(int xpAwarded) {
    return RoammateMessage(
      text: 'Unlocked New Region +$xpAwarded XP',
      speech: 'New region unlocked. You earned $xpAwarded XP.',
    );
  }

  /// Message produced when a hazard is detected nearby.
  factory RoammateMessage.hazardNearby({
    required String hazardCategoryLabel,
    required int distanceMeters,
  }) {
    return RoammateMessage(
      text: 'Hazard Nearby: $hazardCategoryLabel ($distanceMeters m away)',
      speech:
          'Caution: $hazardCategoryLabel reported $distanceMeters meters away.',
    );
  }

  /// Message produced when recommending a contextual location during a journey.
  factory RoammateMessage.journeyRecommendation({
    required String placeName,
    double? rating,
    int? distanceMeters,
    String? regionName,
  }) {
    final ratingPart = rating != null ? ' ★ $rating' : '';
    final distancePart = distanceMeters != null
        ? ' • ${distanceMeters}m away'
        : '';
    final text = 'Roammate suggests: $placeName$ratingPart$distancePart';

    final ratingSpeech = rating != null ? ', rated $rating' : '';
    final regionSpeech = regionName != null && regionName.isNotEmpty
        ? ' in $regionName'
        : '';
    final distanceSpeech = distanceMeters != null
        ? ', $distanceMeters meters away'
        : '';
    final speech =
        'Roammate recommends $placeName$regionSpeech$ratingSpeech$distanceSpeech.';

    return RoammateMessage(text: text, speech: speech);
  }
}
