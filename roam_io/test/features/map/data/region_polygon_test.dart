import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/data/region_polygon.dart';

void main() {
  group('RegionPolygon.fromJson', () {
    test('maps area_square_metres to areaSquareMetres', () {
      final polygon = RegionPolygon.fromJson(<String, dynamic>{
        'id': 'region-1',
        'name': 'Region One',
        'area_square_metres': '12345.67',
        'geometry': _polygonGeometry,
      });

      expect(polygon.areaSquareMetres, 12345.67);
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
