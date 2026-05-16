/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Tests region polygon cache preservation of square-metre area values.
 */

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/data/region_polygon.dart';
import 'package:roam_io/features/map/data/region_polygon_cache.dart';

void main() {
  group('RegionPolygonCache', () {
    test(
      'preserves existing areaSquareMetres when later region lacks area',
      () {
        final cache = RegionPolygonCache();
        final withArea = _region(areaSquareMetres: 4000000);
        final withoutArea = _region(areaSquareMetres: null);

        final firstResult = cache.cacheRegion(
          region: withArea,
          isVisited: false,
          isCurrentRegion: false,
          onRegionTapped: (_, _) {},
        );
        final secondResult = cache.cacheRegion(
          region: withoutArea,
          isVisited: false,
          isCurrentRegion: false,
          onRegionTapped: (_, _) {},
        );

        expect(firstResult.wasAdded, isTrue);
        expect(firstResult.region.areaSquareMetres, 4000000);
        expect(secondResult.wasAdded, isFalse);
        expect(secondResult.region.areaSquareMetres, 4000000);
        expect(cache.regionForId('region-1')?.areaSquareMetres, 4000000);
      },
    );

    test('fresh API area replaces older cached null area', () {
      final cache = RegionPolygonCache();
      final withoutArea = _region(areaSquareMetres: null);
      final withArea = _region(areaSquareMetres: 4000000);

      final firstResult = cache.cacheRegion(
        region: withoutArea,
        isVisited: false,
        isCurrentRegion: false,
        onRegionTapped: (_, _) {},
      );
      final secondResult = cache.cacheRegion(
        region: withArea,
        isVisited: false,
        isCurrentRegion: false,
        onRegionTapped: (_, _) {},
      );

      expect(firstResult.region.areaSquareMetres, isNull);
      expect(secondResult.region.areaSquareMetres, 4000000);
      expect(cache.regionForId('region-1')?.areaSquareMetres, 4000000);
    });

    test(
      'keeps unvisited regions fogged even when heatmap intensity exists',
      () {
        final cache = RegionPolygonCache();

        cache.cacheRegion(
          region: _region(areaSquareMetres: 4000000),
          isVisited: false,
          isCurrentRegion: false,
          onRegionTapped: (_, _) {},
          heatmapIntensity: 1,
        );

        final polygon = cache.polygons.single;

        expect(polygon.fillColor, const Color(0xCC080808));
      },
    );
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
