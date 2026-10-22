/*
 * Author: Sam Sutherland
 * Last Modified: 06/10/2026
 * Description:
 *   Verifies Roammate voice preference mapping on user profiles.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';

void main() {
  test('Roammate voice is disabled by default for existing profiles', () {
    final profile = ProfileModel.fromMap(<String, dynamic>{
      'uid': 'user-1',
      'username': 'traveller',
      'displayName': 'Traveller',
      'email': 'traveller@example.com',
      'createdAt': '2026-10-06T10:00:00.000',
      'updatedAt': '2026-10-06T10:00:00.000',
    });

    expect(profile.roammateVoiceEnabled, isFalse);
  });

  test('Roammate voice preference round-trips through profile mapping', () {
    final profile = ProfileModel(
      uid: 'user-1',
      username: 'traveller',
      displayName: 'Traveller',
      email: 'traveller@example.com',
      createdAt: DateTime(2026, 10, 6, 10),
      updatedAt: DateTime(2026, 10, 6, 11),
      roammateVoiceEnabled: true,
    );

    final restored = ProfileModel.fromMap(profile.toMap());

    expect(profile.toMap()['roammateVoiceEnabled'], isTrue);
    expect(restored.roammateVoiceEnabled, isTrue);
  });
}
