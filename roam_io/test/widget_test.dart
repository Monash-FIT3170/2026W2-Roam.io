import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';

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
    expect(profile.xp, 0);
    expect(profile.level, 1);
  });

  test('ProfileModel derives level from xp when missing', () {
    final profile = ProfileModel.fromMap(<String, dynamic>{
      'uid': 'user-1',
      'username': 'traveller',
      'displayName': 'Traveller',
      'email': 'traveller@example.com',
      'createdAt': '2026-05-01T10:00:00.000',
      'updatedAt': '2026-05-01T10:00:00.000',
      'xp': 250,
    });

    expect(profile.level, 3);
  });

  test('ProfileModel writes profile fields to Firestore map', () {
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
}
