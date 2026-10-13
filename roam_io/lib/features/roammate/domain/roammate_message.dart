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
}
