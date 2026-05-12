import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/data/region_polygon.dart';
import 'package:roam_io/features/map/data/tile_unlock_xp_service.dart';
import 'package:roam_io/features/profile/domain/xp_reward_config.dart';

void main() {
  group('TileUnlockXpService', () {
    test('awards area-based XP rather than the flat base value', () async {
      final awardedXp = <int>[];
      final service = TileUnlockXpService(
        addXp: (xpToAdd) async => awardedXp.add(xpToAdd),
      );

      final xp = await service.awardForUnlockedPolygon(
        _region(areaSquareMetres: 4000000),
      );

      expect(xp, 100);
      expect(xp, isNot(XpRewardConfig.baseTileUnlockXp));
      expect(awardedXp, <int>[100]);
    });

    test('uses minimum fallback XP when polygon area is missing', () async {
      final awardedXp = <int>[];
      final service = TileUnlockXpService(
        addXp: (xpToAdd) async => awardedXp.add(xpToAdd),
      );

      final xp = await service.awardForUnlockedPolygon(
        _region(areaSquareMetres: null),
      );

      expect(xp, XpRewardConfig.minTileUnlockXp);
      expect(awardedXp, <int>[XpRewardConfig.minTileUnlockXp]);
    });
  });
}

RegionPolygon _region({required double? areaSquareMetres}) {
  return RegionPolygon(
    id: 'region-1',
    name: 'Region One',
    areaSquareMetres: areaSquareMetres,
    geometry: _polygonGeometry,
  );
}

const Map<String, dynamic> _polygonGeometry = <String, dynamic>{
  'type': 'Polygon',
  'coordinates': <dynamic>[
    <dynamic>[
      <double>[144.0, -37.0],
      <double>[145.0, -37.0],
      <double>[145.0, -38.0],
      <double>[144.0, -38.0],
      <double>[144.0, -37.0],
    ],
  ],
};
