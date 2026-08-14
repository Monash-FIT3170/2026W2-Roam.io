/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 17/05/2026
 * Description:
 *   Tests region polygon cache preservation of square-metre area values and
 *   verifies that unvisited polygons stay fogged when heatmap intensity exists.
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
      'renders nothing for unvisited regions, even with heatmap intensity',
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

        // Fog is no longer a black polygon per census tile. It is a single
        // animated cloud layer above the map, drawn as the screen minus holes
        // for explored ground, so unexplored tiles must contribute nothing —
        // per-tile fills produced seams and double-blended shared edges.
        //
        // Heatmap intensity must still not leak through onto an unvisited tile.
        expect(polygon.fillColor, const Color(0x00000000));
        expect(polygon.strokeColor, const Color(0x00000000));
        expect(polygon.strokeWidth, 0);
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
