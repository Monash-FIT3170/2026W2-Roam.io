/*
 * Author: [Insert Name Here]
 * Last Modified: 6/05/2026
 * Description:
 *   Verifies profile model mapping behaviour for the dark mode preference
 *   stored in Firestore.
 */

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/domain/map_styles.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';

/// Runs profile model serialization and compatibility tests.
void main() {
  test('ProfileModel defaults missing dark mode preference to false', () {
    final profile = ProfileModel.fromMap(<String, dynamic>{
      'uid': 'user-1',
      'username': 'traveller',
      'displayName': 'Traveller',
      'email': 'traveller@example.com',
      'createdAt': '2026-05-01T10:00:00.000',
      'updatedAt': '2026-05-01T10:00:00.000',
    });

    expect(profile.darkModeEnabled, isFalse);
  });

  test('ProfileModel writes dark mode preference to Firestore map', () {
    final now = DateTime(2026, 5, 1, 10);
    final profile = ProfileModel(
      uid: 'user-1',
      username: 'traveller',
      displayName: 'Traveller',
      email: 'traveller@example.com',
      createdAt: now,
      updatedAt: now,
      darkModeEnabled: true,
    );

    expect(profile.toMap()['darkModeEnabled'], isTrue);
  });

  test(
    'ProfileModel copyWith preserves profile data when toggling dark mode',
    () {
      final createdAt = DateTime(2026, 5, 1, 10);
      final updatedAt = DateTime(2026, 5, 1, 11);
      final profile = ProfileModel(
        uid: 'user-1',
        username: 'traveller',
        displayName: 'Traveller',
        email: 'traveller@example.com',
        photoUrl: 'https://example.com/profile.jpg',
        photoHash: 'photo-hash',
        createdAt: createdAt,
        updatedAt: updatedAt,
        darkModeEnabled: false,
      );

      final copied = profile.copyWith(darkModeEnabled: true);

      expect(copied.darkModeEnabled, isTrue);
      expect(copied.uid, profile.uid);
      expect(copied.username, profile.username);
      expect(copied.displayName, profile.displayName);
      expect(copied.email, profile.email);
      expect(copied.photoUrl, profile.photoUrl);
      expect(copied.photoHash, profile.photoHash);
      expect(copied.createdAt, profile.createdAt);
      expect(copied.updatedAt, profile.updatedAt);
    },
  );

  test('MapStyles returns dark style for dark brightness', () {
    expect(MapStyles.forBrightness(Brightness.dark), MapStyles.dark);
  });

  test('MapStyles clears custom style for light brightness', () {
    expect(MapStyles.forBrightness(Brightness.light), isNull);
  });

  test('MapStyles dark style is valid Google Maps JSON', () {
    final decoded = jsonDecode(MapStyles.dark);

    expect(decoded, isA<List<dynamic>>());
    expect(decoded, isNotEmpty);
    expect(
      decoded,
      contains(
        isA<Map<String, dynamic>>().having(
          (entry) => entry['featureType'],
          'featureType',
          'road',
        ),
      ),
    );
  });
}
