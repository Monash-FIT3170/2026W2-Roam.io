/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Calculates and writes area-based XP rewards for first-time region unlocks.
 */

import '../../auth/data/auth_repository.dart';
import '../../profile/domain/xp_reward_config.dart';
import 'region_polygon.dart';

/// Awards profile XP for first-time tile unlocks after persistence succeeds.
class TileUnlockXpService {
  TileUnlockXpService({Future<bool> Function(int xpToAdd)? addXp})
    : _addXp = addXp ?? _defaultAddXp;

  final Future<bool> Function(int xpToAdd) _addXp;

  /// Calculates unlock XP from the polygon's confirmed square-metre area so
  /// larger regions can reward more XP without using a flat unlock value.
  int xpForUnlockedPolygon(RegionPolygon polygon) {
    return XpRewardConfig.tileUnlockXpForArea(
      tileAreaSquareMetres: polygon.areaSquareMetres,
    );
  }

  /// Adds the area-based unlock XP through the injected writer.
  ///
  /// MapPage injects AuthProvider.addXp so local profile XP, level, and pending
  /// level-up state update immediately after the Firestore write succeeds. The
  /// result records whether a level-up happened so normal unlock toast feedback
  /// can be skipped while the level-up celebration is shown.
  Future<TileUnlockXpResult> awardForUnlockedPolygon(
    RegionPolygon polygon,
  ) async {
    final xpToAdd = xpForUnlockedPolygon(polygon);
    final didLevelUp = await _addXp(xpToAdd);
    return TileUnlockXpResult(xpAwarded: xpToAdd, didLevelUp: didLevelUp);
  }

  static Future<bool> _defaultAddXp(int xpToAdd) async {
    await AuthRepository().addXp(xpToAdd);
    return false;
  }
}

/// Result of awarding XP for a first-time polygon unlock.
class TileUnlockXpResult {
  const TileUnlockXpResult({required this.xpAwarded, required this.didLevelUp});

  final int xpAwarded;
  final bool didLevelUp;
}
