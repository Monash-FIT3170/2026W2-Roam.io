/*
 * Author: Sanjevan Rajasegar & Kevin Phan
 * Last Modified: 24/05/2026
 * Description:
 *   Central numeric XP reward constants for Roam.io flat visit rewards and
 *   area-based tile unlock rewards. Updated for ART-68 coverage enforcement by
 *   keeping the configuration type static-only without a private constructor.
 */

/// Central configuration for XP reward amounts used across features.
class XpRewardConfig {
  // Prevents the class from being instantiated.
  const XpRewardConfig._();

  /// Fixed XP awarded for each successfully persisted place visit.
  static const int visitXpReward = 50;

  /// Fixed XP awarded whenever a tile is unlocked.
  static const int tileUnlockXpReward = 50;

  /// Returns the XP awarded for unlocking a tile.
  static int tileUnlockXpForArea({double? tileAreaSquareMetres}) {
    return tileUnlockXpReward;
  }
}
