/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Tests region polygon cache preservation of square-metre area values.
 */

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

        cache.cacheRegion(
          region: withArea,
          isVisited: false,
          isCurrentRegion: false,
          onRegionTapped: (_, _) {},
        );
        cache.cacheRegion(
          region: withoutArea,
          isVisited: false,
          isCurrentRegion: false,
          onRegionTapped: (_, _) {},
        );

        expect(cache.regionForId('region-1')?.areaSquareMetres, 4000000);
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
