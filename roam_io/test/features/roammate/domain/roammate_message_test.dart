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

  test('journeyRecommendation provides matching text and speech output', () {
    final message = RoammateMessage.journeyRecommendation(
      placeName: 'Matheson Library',
      rating: 4.8,
      distanceMeters: 180,
      regionName: 'Monash Clayton',
    );

    expect(
      message.text,
      'Roammate suggests: Matheson Library ★ 4.8 • 180m away',
    );
    expect(
      message.speech,
      'Roammate recommends Matheson Library in Monash Clayton, rated 4.8, 180 meters away.',
    );
  });

  test('tileEntered with no places says there is nothing new', () {
    final message = RoammateMessage.tileEntered(
      regionName: 'Clayton',
      placeNames: const <String>[],
    );

    expect(message.text, 'Entered Clayton');
    expect(message.speech, 'You have entered Clayton. No new locations here.');
  });

  test('tileEntered with one place uses the singular', () {
    final message = RoammateMessage.tileEntered(
      regionName: 'Clayton',
      placeNames: const <String>['Matheson Library'],
    );

    expect(message.text, 'Entered Clayton • 1 locations');
    expect(
      message.speech,
      'You have entered Clayton. There is 1 location here: Matheson Library.',
    );
  });

  test('tileEntered names up to three places', () {
    final message = RoammateMessage.tileEntered(
      regionName: 'Clayton',
      placeNames: const <String>['A', 'B', 'C'],
    );

    expect(message.text, 'Entered Clayton • 3 locations');
    expect(
      message.speech,
      'You have entered Clayton. There are 3 locations here: A, B, C.',
    );
  });

  test('tileEntered summarises places beyond the first three', () {
    final message = RoammateMessage.tileEntered(
      regionName: 'Clayton',
      placeNames: const <String>['A', 'B', 'C', 'D', 'E'],
    );

    expect(message.text, 'Entered Clayton • 5 locations');
    expect(
      message.speech,
      'You have entered Clayton. There are 5 locations here: A, B, C and 2 more.',
    );
  });
}
