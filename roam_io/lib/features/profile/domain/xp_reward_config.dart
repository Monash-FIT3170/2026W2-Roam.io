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

  /// XP awarded for a tile with the reference square-metre area.
  static const int baseTileUnlockXp = 50;

  /// Minimum XP awarded for unlocking a tile.
  static const int minTileUnlockXp = 25;

  /// Maximum XP awarded for unlocking a tile.
  static const int maxTileUnlockXp = 200;

  /// Area in square metres that maps to the base tile unlock XP.
  static const double referenceTileAreaSquareMetres = 1000000.0;

  /// Returns the XP awarded for unlocking a tile.
  ///
  /// [tileAreaSquareMetres] must be an already-calculated polygon area in
  /// square metres. The square-root scale makes larger polygons worth more XP
  /// while preventing very large polygons from dominating progression. Invalid
  /// or missing areas use the minimum reward so unlocks have a safe fallback.
  static int tileUnlockXpForArea({double? tileAreaSquareMetres}) {
    if (tileAreaSquareMetres == null ||
        tileAreaSquareMetres <= 0 ||
        !tileAreaSquareMetres.isFinite) {
      return minTileUnlockXp;
    }

    final scaledXp =
        baseTileUnlockXp *
        math.sqrt(tileAreaSquareMetres / referenceTileAreaSquareMetres);

    return scaledXp.round().clamp(minTileUnlockXp, maxTileUnlockXp);
  }
}
