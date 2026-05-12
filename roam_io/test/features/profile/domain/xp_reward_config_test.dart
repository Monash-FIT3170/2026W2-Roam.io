/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Tests area-based polygon unlock XP reward bounds and fallback behavior.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/profile/domain/xp_reward_config.dart';

void main() {
  group('XpRewardConfig tile unlock rewards', () {
    test('keeps the base tile unlock reward as the tuning baseline', () {
      expect(XpRewardConfig.baseTileUnlockXp, 50);
    });

    test('small polygon area returns at least the minimum reward', () {
      expect(
        XpRewardConfig.tileUnlockXpForArea(tileAreaSquareMetres: 1),
        XpRewardConfig.minTileUnlockXp,
      );
    });

    test('reference polygon area returns the base reward', () {
      expect(
        XpRewardConfig.tileUnlockXpForArea(
          tileAreaSquareMetres: XpRewardConfig.referenceTileAreaSquareMetres,
        ),
        XpRewardConfig.baseTileUnlockXp,
      );
    });

    test('larger polygon area returns more XP than smaller polygon area', () {
      final smallerXp = XpRewardConfig.tileUnlockXpForArea(
        tileAreaSquareMetres: 1000000,
      );
      final largerXp = XpRewardConfig.tileUnlockXpForArea(
        tileAreaSquareMetres: 4000000,
      );

      expect(largerXp, greaterThan(smallerXp));
    });

    test('very large polygon area is capped at the maximum reward', () {
      expect(
        XpRewardConfig.tileUnlockXpForArea(tileAreaSquareMetres: 1000000000),
        XpRewardConfig.maxTileUnlockXp,
      );
    });

    test('invalid or zero area returns the minimum reward', () {
      expect(
        XpRewardConfig.tileUnlockXpForArea(),
        XpRewardConfig.minTileUnlockXp,
      );
      expect(
        XpRewardConfig.tileUnlockXpForArea(tileAreaSquareMetres: 0),
        XpRewardConfig.minTileUnlockXp,
      );
      expect(
        XpRewardConfig.tileUnlockXpForArea(tileAreaSquareMetres: -1),
        XpRewardConfig.minTileUnlockXp,
      );
      expect(
        XpRewardConfig.tileUnlockXpForArea(tileAreaSquareMetres: double.nan),
        XpRewardConfig.minTileUnlockXp,
      );
      expect(
        XpRewardConfig.tileUnlockXpForArea(
          tileAreaSquareMetres: double.infinity,
        ),
        XpRewardConfig.minTileUnlockXp,
      );
    });
  });
}
