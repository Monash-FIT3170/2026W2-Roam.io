/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Tests region polygon parsing, including square-metre area from the API.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/data/region_polygon.dart';

void main() {
  group('RegionPolygon.fromJson', () {
    test('parses double area_square_metres into areaSquareMetres', () {
      final polygon = RegionPolygon.fromJson(<String, dynamic>{
        'id': 'region-1',
        'name': 'Region One',
        'area_square_metres': 4000000.0,
        'geometry': _polygonGeometry,
      });

      expect(polygon.areaSquareMetres, 4000000.0);
    });

    test('parses integer area_square_metres into areaSquareMetres', () {
      final polygon = RegionPolygon.fromJson(<String, dynamic>{
        'id': 'region-1',
        'name': 'Region One',
        'area_square_metres': 4000000,
        'geometry': _polygonGeometry,
      });

      expect(polygon.areaSquareMetres, 4000000.0);
    });

    test('parses string area_square_metres into areaSquareMetres', () {
      final polygon = RegionPolygon.fromJson(<String, dynamic>{
        'id': 'region-1',
        'name': 'Region One',
        'area_square_metres': '4000000.0',
        'geometry': _polygonGeometry,
      });

      expect(polygon.areaSquareMetres, 4000000.0);
    });

    test('parses camel-case area aliases when API clients differ', () {
      final polygon = RegionPolygon.fromJson(<String, dynamic>{
        'id': 'region-1',
        'name': 'Region One',
        'areaSquareMetres': 54321.0,
        'geometry': _polygonGeometry,
      });

      expect(polygon.areaSquareMetres, 54321.0);
    });

    test('preserves null when area_square_metres is missing or invalid', () {
      final missingArea = RegionPolygon.fromJson(<String, dynamic>{
        'id': 'region-1',
        'name': 'Region One',
        'geometry': _polygonGeometry,
      });
      final invalidArea = RegionPolygon.fromJson(<String, dynamic>{
        'id': 'region-2',
        'name': 'Region Two',
        'area_square_metres': 'not-a-number',
        'geometry': _polygonGeometry,
      });

      expect(missingArea.areaSquareMetres, isNull);
      expect(invalidArea.areaSquareMetres, isNull);
    });
  });
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
