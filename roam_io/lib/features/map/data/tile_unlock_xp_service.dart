/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Calculates and writes area-based XP rewards for first-time region unlocks.
 *   Only reports xpAwarded when the canonical XP award actually succeeded.
 */

import 'package:flutter/foundation.dart';

import '../../auth/data/auth_repository.dart';
import '../../profile/domain/xp_award_result.dart';
import '../../profile/domain/xp_event.dart';
import '../../profile/domain/xp_reward_config.dart';
import 'region_polygon.dart';

/// Awards profile XP for first-time tile unlocks after persistence succeeds.
class TileUnlockXpService {
  TileUnlockXpService({Future<XpAwardResult> Function(int xpToAdd)? addXp})
    : _addXp = addXp ?? _defaultAddXp;

  final Future<XpAwardResult> Function(int xpToAdd) _addXp;

  /// Calculates unlock XP from the polygon's confirmed square-metre area so
  /// larger regions can reward more XP without using a flat unlock value.
  ///
  /// The area originates from backend area_square_metres; null or invalid area
  /// is the only path that should fall back to the 50 XP minimum.
  int xpForUnlockedPolygon(RegionPolygon polygon) {
    final xp = XpRewardConfig.tileUnlockXpForArea(
      tileAreaSquareMetres: polygon.areaSquareMetres,
    );

    if (kDebugMode) {
      debugPrint(
        '[TileUnlockXpService] region=${polygon.id} '
        'areaSquareMetres=${polygon.areaSquareMetres} xp=$xp',
      );
    }

    return xp;
  }

  /// Adds the area-based unlock XP through the injected writer.
  ///
  /// MapPage injects AuthProvider.addXp so local profile XP, level, and pending
  /// level-up state update immediately after the Firestore write succeeds. The
  /// result only reports xpAwarded when the canonical award succeeded.
  Future<TileUnlockXpResult> awardForUnlockedPolygon(
    RegionPolygon polygon,
  ) async {
    final xpToAdd = xpForUnlockedPolygon(polygon);
    final award = await _addXp(xpToAdd);

    if (!award.succeeded) {
      return const TileUnlockXpResult(
        succeeded: false,
        xpAwarded: 0,
        didLevelUp: false,
      );
    }

    return TileUnlockXpResult(
      succeeded: true,
      xpAwarded: award.amount,
      didLevelUp: award.didLevelUp,
    );
  }

  static Future<XpAwardResult> _defaultAddXp(int xpToAdd) {
    return AuthRepository().addXp(xpToAdd, source: XpEventSource.tileUnlock);
  }
}

/// Result of awarding XP for a first-time polygon unlock.
class TileUnlockXpResult {
  const TileUnlockXpResult({
    required this.succeeded,
    required this.xpAwarded,
    required this.didLevelUp,
  });

  /// Whether the canonical XP award was persisted.
  final bool succeeded;

  /// XP amount awarded; 0 when [succeeded] is false.
  final int xpAwarded;

  final bool didLevelUp;
}
