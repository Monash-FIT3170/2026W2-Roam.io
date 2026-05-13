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
      expect(XpRewardConfig.minTileUnlockXp, 50);
      expect(XpRewardConfig.maxTileUnlockXp, 200);
    });

    test('maps valid polygon areas to fixed game reward tiers', () {
      expect(XpRewardConfig.tileUnlockXpForArea(tileAreaSquareMetres: 1), 50);
      expect(
        XpRewardConfig.tileUnlockXpForArea(tileAreaSquareMetres: 3999999),
        50,
      );
      expect(
        XpRewardConfig.tileUnlockXpForArea(tileAreaSquareMetres: 4000000),
        75,
      );
      expect(
        XpRewardConfig.tileUnlockXpForArea(tileAreaSquareMetres: 7999999),
        75,
      );
      expect(
        XpRewardConfig.tileUnlockXpForArea(tileAreaSquareMetres: 8000000),
        100,
      );
      expect(
        XpRewardConfig.tileUnlockXpForArea(tileAreaSquareMetres: 15999999),
        100,
      );
      expect(
        XpRewardConfig.tileUnlockXpForArea(tileAreaSquareMetres: 16000000),
        150,
      );
      expect(
        XpRewardConfig.tileUnlockXpForArea(tileAreaSquareMetres: 31999999),
        150,
      );
      expect(
        XpRewardConfig.tileUnlockXpForArea(tileAreaSquareMetres: 32000000),
        175,
      );
      expect(
        XpRewardConfig.tileUnlockXpForArea(tileAreaSquareMetres: 63999999),
        175,
      );
      expect(
        XpRewardConfig.tileUnlockXpForArea(tileAreaSquareMetres: 64000000),
        200,
      );
      expect(
        XpRewardConfig.tileUnlockXpForArea(tileAreaSquareMetres: 1000000000),
        200,
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
