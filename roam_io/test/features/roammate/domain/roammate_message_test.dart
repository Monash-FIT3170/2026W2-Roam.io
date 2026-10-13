/*
 * Author: Sam Sutherland
 * Last Modified: 06/10/2026
 * Description:
 *   Verifies text and spoken copy for supported Roammate messages.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/roammate/domain/roammate_message.dart';

void main() {
  test('tileUnlocked provides matching text and speech output', () {
    final message = RoammateMessage.tileUnlocked(75);

    expect(message.text, 'Unlocked New Region +75 XP');
    expect(message.speech, 'New region unlocked. You earned 75 XP.');
  });

  test('hazardNearby provides matching text and speech output', () {
    final message = RoammateMessage.hazardNearby(
      hazardCategoryLabel: 'Pothole',
      distanceMeters: 120,
    );

    expect(message.text, 'Hazard Nearby: Pothole (120 m away)');
    expect(message.speech, 'Caution: Pothole reported 120 meters away.');
  });
}
