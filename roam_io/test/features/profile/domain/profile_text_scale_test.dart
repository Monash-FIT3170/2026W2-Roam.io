/*
 * Description:
 *   Verifies the Larger Text scale on user profiles: default, Firestore
 *   mapping, clamping to the slider range, copyWith, and ProfileService
 *   persistence.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';
import 'package:roam_io/services/profile_service.dart';

Map<String, dynamic> _map({Object? scale}) => <String, dynamic>{
  'uid': 'user-1',
  'username': 'traveller',
  'displayName': 'Traveller',
  'email': 'traveller@example.com',
  'createdAt': '2026-10-06T10:00:00.000',
  'updatedAt': '2026-10-06T10:00:00.000',
  'largerTextScale': ?scale,
};

void main() {
  test('defaults to the standard Larger Text scale', () {
    expect(ProfileModel.fromMap(_map()).largerTextScale, 1.2);
    expect(ProfileModel.defaultTextScale, 1.2);
  });

  test('reads an integer or decimal scale from Firestore', () {
    expect(ProfileModel.fromMap(_map(scale: 1.5)).largerTextScale, 1.5);
    expect(ProfileModel.fromMap(_map(scale: 2)).largerTextScale, 1.8);
  });

  test('clamps out-of-range scales to the slider bounds', () {
    expect(
      ProfileModel.fromMap(_map(scale: 0.2)).largerTextScale,
      ProfileModel.minTextScale,
    );
    expect(
      ProfileModel.fromMap(_map(scale: 9.0)).largerTextScale,
      ProfileModel.maxTextScale,
    );
  });

  test('scale round-trips through toMap and copyWith', () {
    final profile = ProfileModel.fromMap(_map()).copyWith(largerTextScale: 1.6);

    expect(profile.toMap()['largerTextScale'], 1.6);
    expect(ProfileModel.fromMap(profile.toMap()).largerTextScale, 1.6);
    expect(profile.copyWith(highContrastEnabled: true).largerTextScale, 1.6);
  });

  test('ProfileService persists the scale and leaves other fields', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('profiles').doc('user-1').set(<String, dynamic>{
      'uid': 'user-1',
      'largerTextEnabled': true,
    });
    final service = ProfileService(firestore: firestore);

    await service.updateLargerTextScale(uid: 'user-1', scale: 1.4);

    final data = (await firestore.collection('profiles').doc('user-1').get())
        .data()!;
    expect(data['largerTextScale'], 1.4);
    expect(data['largerTextEnabled'], isTrue);
    expect(data['updatedAt'], isA<String>());
  });
}
