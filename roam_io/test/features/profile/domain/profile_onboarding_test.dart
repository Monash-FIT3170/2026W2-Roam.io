import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';
import 'package:roam_io/services/profile_service.dart';

void main() {
  test('legacy accounts remain completed; pending status survives edits', () {
    expect(ProfileModel.fromMap({}).onboardingCompleted, isTrue);
    final pending = ProfileModel.fromMap({
      'uid': 'new-user',
      'onboardingCompleted': false,
    });
    final edited = pending.copyWith(displayName: 'Explorer');
    expect(ProfileModel.fromMap(edited.toMap()).onboardingCompleted, isFalse);
    expect(
      ProfileModel.fromMap(
        edited.copyWith(onboardingCompleted: true).toMap(),
      ).onboardingCompleted,
      isTrue,
    );
  });

  test(
    'completion survives reload without changing other accounts or XP',
    () async {
      final firestore = FakeFirebaseFirestore();
      final profiles = firestore.collection('profiles');
      for (final uid in ['new-user', 'other-user']) {
        await profiles.doc(uid).set({
          'uid': uid,
          'onboardingCompleted': false,
          'xp': 150,
          'level': 2,
          'username': uid,
        });
      }
      final service = ProfileService(firestore: firestore);
      await service.completeOnboarding('new-user');
      await service.completeOnboarding('new-user');
      final reloaded = await service.getProfile('new-user');
      expect(reloaded!.onboardingCompleted, isTrue);
      expect(reloaded.xp, 150);
      expect(reloaded.level, 2);
      expect(reloaded.username, 'new-user');
      expect(
        (await service.getProfile('other-user'))!.onboardingCompleted,
        isFalse,
      );
    },
  );
}
