import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/journeys/screens/journeys_screen.dart';
import 'package:roam_io/features/map/domain/map_styles.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';
import 'package:roam_io/shared/widgets/level_up_celebration.dart';

/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 6/05/2026
 * Description:
 *   Verifies profile model mapping behaviour for the dark mode preference
 *   stored in Firestore.
 */

/// Runs profile model serialization and compatibility tests.
void main() {
  group('ProfileModel Firestore mapping', () {
    test('defaults missing optional fields for legacy profiles', () {
      final profile = ProfileModel.fromMap(<String, dynamic>{
        'uid': 'user-1',
        'username': 'traveller',
        'displayName': 'Traveller',
        'email': 'traveller@example.com',
        'createdAt': '2026-05-01T10:00:00.000',
        'updatedAt': '2026-05-01T10:00:00.000',
      });

      expect(profile.darkModeEnabled, isFalse);
      expect(profile.xp, 0);
      expect(profile.level, 1);
    });

    test('derives level from xp when the level field is missing', () {
      final profile = ProfileModel.fromMap(<String, dynamic>{
        'uid': 'user-1',
        'username': 'traveller',
        'displayName': 'Traveller',
        'email': 'traveller@example.com',
        'createdAt': '2026-05-01T10:00:00.000',
        'updatedAt': '2026-05-01T10:00:00.000',
        'xp': 250,
      });

      expect(profile.level, 2);
    });

    test('writes XP and level fields to a Firestore map', () {
      final now = DateTime(2026, 5, 1, 10);
      final profile = ProfileModel(
        uid: 'user-1',
        username: 'traveller',
        displayName: 'Traveller',
        email: 'traveller@example.com',
        createdAt: now,
        updatedAt: now,
        darkModeEnabled: true,
        xp: 25,
        level: 1,
      );

      expect(profile.toMap()['darkModeEnabled'], isTrue);
      expect(profile.toMap()['xp'], 25);
      expect(profile.toMap()['level'], 1);
    });
  });

  group('QAP XP unit tests', () {
    test('ART-65 increases XP required as levels get higher', () {
      expect(ProfileModel.xpForLevel(1), 100);
      expect(ProfileModel.xpForLevel(2), 300);
      expect(ProfileModel.xpForLevel(3), 500);
      expect(ProfileModel.xpForLevel(4), 700);
      expect(
        ProfileModel.xpForLevel(4),
        greaterThan(ProfileModel.xpForLevel(3)),
      );
    });

    test('ART-65 converts cumulative XP to levels at exact boundaries', () {
      expect(ProfileModel.levelFromXp(-1), 1);
      expect(ProfileModel.levelFromXp(99), 1);
      expect(ProfileModel.levelFromXp(100), 2);
      expect(ProfileModel.levelFromXp(399), 2);
      expect(ProfileModel.levelFromXp(400), 3);
      expect(ProfileModel.levelFromXp(900), 4);
    });

    test('ART-65 caps cumulative XP calculations at the maximum level', () {
      final maxLevelXp = ProfileModel.totalXpToReachLevel(
        ProfileModel.maxLevel,
      );

      expect(ProfileModel.levelFromXp(maxLevelXp), ProfileModel.maxLevel);
      expect(
        ProfileModel.totalXpToReachLevel(ProfileModel.maxLevel + 1),
        maxLevelXp,
      );
    });
  });

  group('QAP XP widget tests', () {
    testWidgets('ART-64 displays earned XP on every journey card', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: JourneysScreen())),
      );

      expect(find.text('32 XP earned'), findsOneWidget);
      expect(find.text('50 XP earned'), findsOneWidget);
      expect(find.text('84 XP earned'), findsOneWidget);
    });

    testWidgets('ART-53 shows and dismisses the level-up celebration', (
      tester,
    ) async {
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: LevelUpCelebration(
            newLevel: 7,
            onDismiss: () => dismissed = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 900));

      expect(find.text('LEVEL UP!'), findsOneWidget);
      expect(find.text('Level 7'), findsOneWidget);
      expect(find.text('Tap to continue'), findsOneWidget);

      await tester.tap(find.byType(LevelUpCelebration));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));

      expect(dismissed, isTrue);
    });
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

  test('MapStyles applies retro style for light brightness', () {
    expect(MapStyles.forBrightness(Brightness.light), MapStyles.light);
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
