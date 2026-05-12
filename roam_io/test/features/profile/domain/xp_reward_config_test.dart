/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Unit checks for central XP reward constants used by map visit flows.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/profile/domain/xp_reward_config.dart';

void main() {
  test('visit XP reward is fixed at 50', () {
    expect(XpRewardConfig.visitXpReward, 50);
  });
}
