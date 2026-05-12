import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/profile/domain/xp_reward_config.dart';

/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Tests the logic in the xp_reward_config.dart file, ensuring that tile unlock rewards are correctly calculated based on the defined 
 *   parameters.
 */

void main() {
  group('XpRewardConfig tile unlock rewards', () {
    test('uses 50 XP as the base tile unlock reward', () {
      expect(XpRewardConfig.baseTileUnlockXp, 50);
    });

    test('returns the base reward when no tile area is provided', () {
      expect(XpRewardConfig.tileUnlockXpForArea(), 50);
    });

    test('keeps tile unlock rewards fixed when an area is provided', () {
      expect(XpRewardConfig.tileUnlockXpForArea(tileArea: 1250.5), 50);
    });
  });
}
