import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/data/region_polygon.dart';

void main() {
  group('RegionPolygon.fromJson', () {
    test('parses geometry when it is a decoded map', () {
      final polygon = RegionPolygon.fromJson(<String, dynamic>{
        'id': 'r1',
        'name': 'Region One',
        'geometry': <String, dynamic>{
          'type': 'Polygon',
          'coordinates': [
            [
              [144.9, -37.8],
              [145.0, -37.8],
              [145.0, -37.9],
              [144.9, -37.9],
              [144.9, -37.8],
            ],
          ],
        },
      });

      expect(polygon.id, 'r1');
      expect(polygon.name, 'Region One');
      expect(polygon.geometry['type'], 'Polygon');
    });

    test('parses geometry when it is a JSON string', () {
      final geometryString = jsonEncode(<String, dynamic>{
        'type': 'Polygon',
        'coordinates': [
          [
            [144.9, -37.8],
            [145.0, -37.8],
            [145.0, -37.9],
            [144.9, -37.9],
            [144.9, -37.8],
          ],
        ],
      });

      final polygon = RegionPolygon.fromJson(<String, dynamic>{
        'id': 'r2',
        'name': 'Region Two',
        'geometry': geometryString,
      });

      expect(polygon.geometry['type'], 'Polygon');
    });
  });

  group('RegionPolygon.toGooglePolygons', () {
    test('creates one polygon for Polygon geometry', () {
      const region = RegionPolygon(
        id: 'a',
        name: 'A',
        geometry: <String, dynamic>{
          'type': 'Polygon',
          'coordinates': [
            [
              [144.0, -37.0],
              [144.1, -37.0],
              [144.1, -37.1],
              [144.0, -37.1],
              [144.0, -37.0],
            ],
          ],
        },
      );

      final polygons = region.toGooglePolygons();
      expect(polygons, hasLength(1));
      expect(polygons.first.polygonId.value, 'a');
    });

    test('creates multiple polygons for MultiPolygon geometry', () {
      const region = RegionPolygon(
        id: 'multi',
        name: 'Multi',
        geometry: <String, dynamic>{
          'type': 'MultiPolygon',
          'coordinates': [
            [
              [
                [144.0, -37.0],
                [144.05, -37.0],
                [144.05, -37.05],
                [144.0, -37.05],
                [144.0, -37.0],
              ],
            ],
            [
              [
                [144.2, -37.2],
                [144.25, -37.2],
                [144.25, -37.25],
                [144.2, -37.25],
                [144.2, -37.2],
              ],
            ],
          ],
        },
      );

      final polygons = region.toGooglePolygons();
      expect(polygons, hasLength(2));
      expect(polygons.map((p) => p.polygonId.value), ['multi_0', 'multi_1']);
    });

    test('throws for unsupported geometry types', () {
      const region = RegionPolygon(
        id: 'x',
        name: 'X',
        geometry: <String, dynamic>{
          'type': 'LineString',
          'coordinates': [
            [144.0, -37.0],
            [144.1, -37.1],
          ],
        },
      );

      expect(() => region.toGooglePolygons(), throwsException);
    });
  });
}
