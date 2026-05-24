/*
 * Author: Sanjevan Rajasegar & Kevin Phan
 * Last Modified: 24/05/2026
 * Description:
 *   Tests fixed polygon unlock XP rewards and fallback behavior.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/profile/domain/xp_reward_config.dart';

void main() {
  group('XpRewardConfig tile unlock rewards', () {
    test('all polygon areas award fixed XP', () {
      expect(XpRewardConfig.tileUnlockXpForArea(tileAreaSquareMetres: 1), 50);

      expect(
        XpRewardConfig.tileUnlockXpForArea(
          tileAreaSquareMetres: 4000000,
        ),
        50,
      );

      expect(
        XpRewardConfig.tileUnlockXpForArea(
          tileAreaSquareMetres: 1000000000,
        ),
        50,
      );
    });

    test('invalid or missing area still awards fixed XP', () {
      expect(
        XpRewardConfig.tileUnlockXpForArea(),
        50,
      );

      expect(
        XpRewardConfig.tileUnlockXpForArea(
          tileAreaSquareMetres: 0,
        ),
        50,
      );

      expect(
        XpRewardConfig.tileUnlockXpForArea(
          tileAreaSquareMetres: -1,
        ),
        50,
      );

      expect(
        XpRewardConfig.tileUnlockXpForArea(
          tileAreaSquareMetres: double.nan,
        ),
        50,
      );

      expect(
        XpRewardConfig.tileUnlockXpForArea(
          tileAreaSquareMetres: double.infinity,
        ),
        50,
      );
    });
  });
}