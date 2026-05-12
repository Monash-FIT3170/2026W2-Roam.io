/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Defines XP rewards for profile progression events.
 */

/// Central XP reward configuration for profile progression events.
class XpRewardConfig {
  const XpRewardConfig._();

  /// Fixed XP awarded when a user unlocks a tile.
  static const int baseTileUnlockXp = 50;

  /// Returns the XP awarded for unlocking a tile.
  ///
  /// Tile unlocks currently use a fixed reward so that progression remains
  /// predictable. [tileArea] is accepted for the future case where larger
  /// polygons or tiles should scale the reward without moving this calculation
  /// into map or UI code.
  static int tileUnlockXpForArea({double? tileArea}) {
    return baseTileUnlockXp;
  }
}
