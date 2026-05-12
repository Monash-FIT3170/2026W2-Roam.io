import '../../auth/data/auth_repository.dart';
import '../../profile/domain/xp_reward_config.dart';
import 'region_polygon.dart';

/// Awards profile XP for first-time tile unlocks.
class TileUnlockXpService {
  TileUnlockXpService({Future<void> Function(int xpToAdd)? addXp})
    : _addXp = addXp ?? AuthRepository().addXp;

  final Future<void> Function(int xpToAdd) _addXp;

  /// Calculates unlock XP from the polygon's confirmed square-metre area.
  int xpForUnlockedPolygon(RegionPolygon polygon) {
    return XpRewardConfig.tileUnlockXpForArea(
      tileAreaSquareMetres: polygon.areaSquareMetres,
    );
  }

  /// Adds the area-based unlock XP to the signed-in user's profile.
  Future<int> awardForUnlockedPolygon(RegionPolygon polygon) async {
    final xpToAdd = xpForUnlockedPolygon(polygon);
    await _addXp(xpToAdd);
    return xpToAdd;
  }
}
