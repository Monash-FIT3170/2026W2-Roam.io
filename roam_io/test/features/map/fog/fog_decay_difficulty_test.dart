import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/fog/fog_decay_difficulty.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';

void main() {
  test('resolves every difficulty through the central decay policy', () {
    expect(
      getFogDecayDuration(FogDecayDifficulty.monthly),
      const Duration(days: 30),
    );
    expect(
      getFogDecayDuration(FogDecayDifficulty.quarterly),
      const Duration(days: 90),
    );
    expect(
      getFogDecayDuration(FogDecayDifficulty.yearly),
      const Duration(days: 365),
    );
  });

  test('profile serialization saves and restores the selected difficulty', () {
    final profile = _profile(fogDecayDifficulty: FogDecayDifficulty.monthly);

    final restored = ProfileModel.fromMap(profile.toMap());

    expect(profile.toMap()['fogDecayDifficulty'], 'MONTHLY');
    expect(restored.fogDecayDifficulty, FogDecayDifficulty.monthly);
  });

  test('missing or invalid saved preference defaults to quarterly', () {
    expect(
      ProfileModel.fromMap(
        _profile().toMap()..remove('fogDecayDifficulty'),
      ).fogDecayDifficulty,
      FogDecayDifficulty.quarterly,
    );
    expect(
      FogDecayDifficulty.fromStorage('unsupported'),
      FogDecayDifficulty.quarterly,
    );
  });
}

ProfileModel _profile({
  FogDecayDifficulty fogDecayDifficulty = FogDecayDifficulty.quarterly,
}) {
  return ProfileModel(
    uid: 'user-1',
    username: 'traveller',
    displayName: 'Traveller',
    email: 'traveller@example.com',
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 2),
    fogDecayDifficulty: fogDecayDifficulty,
  );
}
