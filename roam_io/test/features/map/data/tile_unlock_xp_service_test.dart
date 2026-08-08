/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Tests area-based tile unlock XP calculation and writer integration.
 *   xpAwarded is only reported when the canonical XP award succeeds.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/data/region_polygon.dart';
import 'package:roam_io/features/map/data/tile_unlock_xp_service.dart';
import 'package:roam_io/features/profile/domain/xp_award_result.dart';
import 'package:roam_io/features/profile/domain/xp_reward_config.dart';

void main() {
  group('TileUnlockXpService', () {
    test('awards area-based XP rather than the flat base value', () async {
      final awardedXp = <int>[];
      final service = TileUnlockXpService(
        addXp: (xpToAdd) async {
          awardedXp.add(xpToAdd);
          return XpAwardResult.success(
            amount: xpToAdd,
            previousXp: 0,
            newXp: xpToAdd,
            previousLevel: 1,
            newLevel: 1,
            historyRecorded: true,
          );
        },
      );

      final result = await service.awardForUnlockedPolygon(
        _region(areaSquareMetres: 4000000),
      );

      expect(result.succeeded, isTrue);
      expect(result.xpAwarded, 50);
      expect(result.didLevelUp, isFalse);
      expect(awardedXp, <int>[50]);
    });

    test('reports when the injected writer triggers a level-up', () async {
      final service = TileUnlockXpService(
        addXp: (xpToAdd) async => XpAwardResult.success(
          amount: xpToAdd,
          previousXp: 90,
          newXp: 90 + xpToAdd,
          previousLevel: 1,
          newLevel: 2,
          historyRecorded: true,
        ),
      );

      final result = await service.awardForUnlockedPolygon(
        _region(areaSquareMetres: 1000000),
      );

      expect(result.succeeded, isTrue);
      expect(result.xpAwarded, 50);
      expect(result.didLevelUp, isTrue);
    });

    test('does not report xpAwarded when the writer fails', () async {
      final service = TileUnlockXpService(
        addXp: (xpToAdd) async => XpAwardResult.failed(amount: xpToAdd),
      );

      final result = await service.awardForUnlockedPolygon(
        _region(areaSquareMetres: 1000000),
      );

      expect(result.succeeded, isFalse);
      expect(result.xpAwarded, 0);
      expect(result.didLevelUp, isFalse);
    });

    test('awards fixed XP when polygon area is missing', () async {
      final awardedXp = <int>[];

      final service = TileUnlockXpService(
        addXp: (xpToAdd) async {
          awardedXp.add(xpToAdd);
          return XpAwardResult.success(
            amount: xpToAdd,
            previousXp: 0,
            newXp: xpToAdd,
            previousLevel: 1,
            newLevel: 1,
            historyRecorded: false,
          );
        },
      );

      final result = await service.awardForUnlockedPolygon(
        _region(areaSquareMetres: null),
      );

      expect(result.succeeded, isTrue);
      expect(result.xpAwarded, XpRewardConfig.tileUnlockXpReward);
      expect(awardedXp, <int>[XpRewardConfig.tileUnlockXpReward]);
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
