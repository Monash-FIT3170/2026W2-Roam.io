import 'dart:math' as math;

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

  /// Minimum XP awarded for unlocking a tile.
  static const int minTileUnlockXp = 25;

  /// Maximum XP awarded for unlocking a tile.
  static const int maxTileUnlockXp = 200;

  /// Area in square metres that maps to the base tile unlock XP.
  static const double referenceTileAreaSquaremetres = 1000000.0;

  /// Returns the XP awarded for unlocking a tile.
  ///
  /// [tileArea] is expected to be in square metres. The square-root scale makes
  /// larger polygons worth more XP while preventing very large polygons from
  /// dominating progression. Invalid or missing areas use the minimum reward so
  /// every valid unlock path can still give a safe fallback reward.
  static int tileUnlockXpForArea({double? tileArea}) {
    if (tileArea == null || tileArea <= 0 || !tileArea.isFinite) {
      return minTileUnlockXp;
    }

    final scaledXp =
        baseTileUnlockXp * math.sqrt(tileArea / referenceTileAreaSquaremetres);

    return scaledXp.round().clamp(minTileUnlockXp, maxTileUnlockXp);
  }
}
