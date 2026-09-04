import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/services/profile_service.dart';
import 'package:roam_io/features/map/fog/fog_decay_difficulty.dart';
import 'package:roam_io/theme/app_theme_mode.dart';

void main() {
  test(
    'ProfileService persists the new and legacy appearance fields',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('profiles').doc('user-1').set(
        <String, dynamic>{'uid': 'user-1'},
      );
      final service = ProfileService(firestore: firestore);

      await service.updateThemeModePreference(
        uid: 'user-1',
        mode: AppThemeMode.dynamic,
      );

      final data = (await firestore.collection('profiles').doc('user-1').get())
          .data()!;
      expect(data['themeMode'], 'dynamic');
      expect(data['darkModeEnabled'], isFalse);
      expect(data['updatedAt'], isA<String>());
    },
  );

  test('ProfileService persists fog decay difficulty', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('profiles').doc('user-1').set(<String, dynamic>{
      'uid': 'user-1',
    });
    final service = ProfileService(firestore: firestore);

    await service.updateFogDecayDifficulty(
      uid: 'user-1',
      difficulty: FogDecayDifficulty.yearly,
    );

    final data = (await firestore.collection('profiles').doc('user-1').get())
        .data()!;
    expect(data['fogDecayDifficulty'], 'YEARLY');
    expect(data['updatedAt'], isA<String>());
  });
}
