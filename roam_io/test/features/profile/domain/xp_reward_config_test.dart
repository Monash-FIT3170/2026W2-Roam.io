import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/profile/domain/xp_reward_config.dart';

/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Tests the logic in the xp_reward_config.dart file, ensuring that tile
 *   unlock rewards are correctly calculated based on the defined parametres.
 */

void main() {
  group('XpRewardConfig tile unlock rewards', () {
    test('keeps the base tile unlock reward as the tuning baseline', () {
      expect(XpRewardConfig.baseTileUnlockXp, 50);
    });

    test('small polygon area returns at least the minimum reward', () {
      expect(
        XpRewardConfig.tileUnlockXpForArea(tileArea: 1),
        XpRewardConfig.minTileUnlockXp,
      );
    });

    test('larger polygon area returns more XP than smaller polygon area', () {
      final smallerXp = XpRewardConfig.tileUnlockXpForArea(tileArea: 1000000);
      final largerXp = XpRewardConfig.tileUnlockXpForArea(tileArea: 4000000);

      expect(largerXp, greaterThan(smallerXp));
    });

    test('very large polygon area is capped at the maximum reward', () {
      expect(
        XpRewardConfig.tileUnlockXpForArea(tileArea: 1000000000),
        XpRewardConfig.maxTileUnlockXp,
      );
    });

    test('invalid or zero area returns the minimum reward', () {
      expect(
        XpRewardConfig.tileUnlockXpForArea(),
        XpRewardConfig.minTileUnlockXp,
      );
      expect(
        XpRewardConfig.tileUnlockXpForArea(tileArea: 0),
        XpRewardConfig.minTileUnlockXp,
      );
      expect(
        XpRewardConfig.tileUnlockXpForArea(tileArea: -1),
        XpRewardConfig.minTileUnlockXp,
      );
      expect(
        XpRewardConfig.tileUnlockXpForArea(tileArea: double.nan),
        XpRewardConfig.minTileUnlockXp,
      );
      expect(
        XpRewardConfig.tileUnlockXpForArea(tileArea: double.infinity),
        XpRewardConfig.minTileUnlockXp,
      );
    });
  });
}
