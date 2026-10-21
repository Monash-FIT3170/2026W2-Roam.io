/*
 * Description:
 *   Verifies the High Contrast and Larger Text preferences on user profiles:
 *   defaults, Firestore mapping, copyWith, and ProfileService persistence.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';
import 'package:roam_io/services/profile_service.dart';

ProfileModel _profile({bool highContrast = false, bool largerText = false}) {
  return ProfileModel(
    uid: 'user-1',
    username: 'traveller',
    displayName: 'Traveller',
    email: 'traveller@example.com',
    createdAt: DateTime(2026, 10, 6, 10),
    updatedAt: DateTime(2026, 10, 6, 11),
    highContrastEnabled: highContrast,
    largerTextEnabled: largerText,
  );
}

void main() {
  test('both preferences are off for profiles that predate them', () {
    final profile = ProfileModel.fromMap(<String, dynamic>{
      'uid': 'user-1',
      'username': 'traveller',
      'displayName': 'Traveller',
      'email': 'traveller@example.com',
      'createdAt': '2026-10-06T10:00:00.000',
      'updatedAt': '2026-10-06T10:00:00.000',
    });

    expect(profile.highContrastEnabled, isFalse);
    expect(profile.largerTextEnabled, isFalse);
  });

  test('preferences round-trip independently through profile mapping', () {
    final profile = _profile(highContrast: true);
    final restored = ProfileModel.fromMap(profile.toMap());

    expect(profile.toMap()['highContrastEnabled'], isTrue);
    expect(profile.toMap()['largerTextEnabled'], isFalse);
    expect(restored.highContrastEnabled, isTrue);
    expect(restored.largerTextEnabled, isFalse);
  });

  test('copyWith changes one preference and keeps the other', () {
    final profile = _profile(highContrast: true);
    final updated = profile.copyWith(largerTextEnabled: true);

    expect(updated.highContrastEnabled, isTrue);
    expect(updated.largerTextEnabled, isTrue);
    expect(profile.largerTextEnabled, isFalse);
  });

  test(
    'ProfileService persists each preference without touching the other',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('profiles').doc('user-1').set(
        <String, dynamic>{'uid': 'user-1', 'largerTextEnabled': true},
      );
      final service = ProfileService(firestore: firestore);

      await service.updateHighContrastPreference(uid: 'user-1', enabled: true);
      var data = (await firestore.collection('profiles').doc('user-1').get())
          .data()!;
      expect(data['highContrastEnabled'], isTrue);
      expect(data['largerTextEnabled'], isTrue);
      expect(data['updatedAt'], isA<String>());

      await service.updateLargerTextPreference(uid: 'user-1', enabled: false);
      data = (await firestore.collection('profiles').doc('user-1').get())
          .data()!;
      expect(data['highContrastEnabled'], isTrue);
      expect(data['largerTextEnabled'], isFalse);
    },
  );
}
