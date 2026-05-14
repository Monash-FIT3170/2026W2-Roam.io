/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Central numeric XP reward constants for Roam.io flat visit rewards and
 *   area-based tile unlock rewards.
 */

/// Central configuration for XP reward amounts used across features.
class XpRewardConfig {
  const XpRewardConfig._();

  /// Fixed XP awarded for each successfully persisted place visit.
  ///
  /// Not derived from polygon area, distance, or place metadata.
  static const int visitXpReward = 50;

  /// Lowest XP awarded for unlocking a valid tile.
  static const int baseTileUnlockXp = 50;

  /// Minimum XP awarded for unlocking a tile.
  static const int minTileUnlockXp = 50;

  /// Maximum XP awarded for unlocking a tile.
  static const int maxTileUnlockXp = 200;

  /// First area threshold above the base tile unlock XP.
  static const double referenceTileAreaSquareMetres = 4000000.0;

  static const double _tier75AreaSquareMetres = 4000000.0;
  static const double _tier100AreaSquareMetres = 8000000.0;
  static const double _tier150AreaSquareMetres = 16000000.0;
  static const double _tier175AreaSquareMetres = 32000000.0;
  static const double _tier200AreaSquareMetres = 64000000.0;

  /// Returns the XP awarded for unlocking a tile.
  ///
  /// [tileAreaSquareMetres] must be an already-calculated polygon area in
  /// square metres. Larger polygons are mapped to fixed game reward tiers.
  /// Invalid or missing areas use the minimum reward so unlocks have a safe
  /// fallback.
  static int tileUnlockXpForArea({double? tileAreaSquareMetres}) {
    if (tileAreaSquareMetres == null ||
        tileAreaSquareMetres <= 0 ||
        !tileAreaSquareMetres.isFinite) {
      return minTileUnlockXp;
    }

    if (tileAreaSquareMetres < _tier75AreaSquareMetres) {
      return 50;
    }
    if (tileAreaSquareMetres < _tier100AreaSquareMetres) {
      return 75;
    }
    if (tileAreaSquareMetres < _tier150AreaSquareMetres) {
      return 100;
    }
    if (tileAreaSquareMetres < _tier175AreaSquareMetres) {
      return 150;
    }
    if (tileAreaSquareMetres < _tier200AreaSquareMetres) {
      return 175;
    }

    return maxTileUnlockXp;
  }
}
