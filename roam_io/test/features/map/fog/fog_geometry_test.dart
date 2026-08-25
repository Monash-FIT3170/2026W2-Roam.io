import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/map/data/region_polygon.dart';
import 'package:roam_io/features/map/fog/fog_geometry.dart';
import 'package:roam_io/features/map/fog/fog_projection.dart';

const LatLng _anchor = LatLng(-37.8136, 144.9631);
const FogProjection _projection = FogProjection(anchor: _anchor);

void main() {
  group('FogGeometry.buildPath', () {
    test('builds a closed path from a simple polygon', () {
      final path = FogGeometry.buildPath(_square(), _projection);

      expect(path.getBounds().isEmpty, isFalse);
      expect(path.contains(_worldCentreOfSquare()), isTrue);
    });

    test('uses evenOdd so inner rings subtract', () {
      final path = FogGeometry.buildPath(_square(), _projection);

      expect(path.fillType, PathFillType.evenOdd);
    });

    test('preserves inner rings as holes', () {
      // RegionPolygon.toGooglePolygons drops these — Google Maps polygons never
      // populated `holes`, so a donut region rendered solid and nobody noticed.
      // The fog punches holes for explored ground, so dropping an inner ring
      // here would clear territory the user has never visited.
      final donut = const RegionPolygon(
        id: 'donut',
        name: 'Donut',
        areaSquareMetres: 1000,
        geometry: <String, dynamic>{
          'type': 'Polygon',
          'coordinates': <dynamic>[
            <dynamic>[
              <double>[144.90, -37.90],
              <double>[145.00, -37.90],
              <double>[145.00, -37.80],
              <double>[144.90, -37.80],
              <double>[144.90, -37.90],
            ],
            <dynamic>[
              <double>[144.93, -37.87],
              <double>[144.97, -37.87],
              <double>[144.97, -37.83],
              <double>[144.93, -37.83],
              <double>[144.93, -37.87],
            ],
          ],
        },
      );

      final path = FogGeometry.buildPath(donut, _projection);

      final insideHole = _projection.latLngToWorld(-37.85, 144.95);
      final insideRing = _projection.latLngToWorld(-37.885, 144.915);

      expect(
        path.contains(insideHole),
        isFalse,
        reason: 'the inner ring must remain fogged',
      );
      expect(path.contains(insideRing), isTrue);
    });

    test('covers every part of a MultiPolygon', () {
      final path = FogGeometry.buildPath(_twoSquares(), _projection);

      expect(path.contains(_projection.latLngToWorld(-37.85, 144.95)), isTrue);
      expect(path.contains(_projection.latLngToWorld(-37.65, 145.15)), isTrue);
    });

    test('returns an empty path for unsupported geometry', () {
      // A bad region should leave that patch fogged, never crash the map.
      final line = const RegionPolygon(
        id: 'line',
        name: 'Line',
        areaSquareMetres: null,
        geometry: <String, dynamic>{
          'type': 'LineString',
          'coordinates': <dynamic>[
            <double>[144.9, -37.9],
            <double>[145.0, -37.8],
          ],
        },
      );

      expect(() => FogGeometry.buildPath(line, _projection), returnsNormally);
      expect(
        FogGeometry.buildPath(line, _projection).getBounds().isEmpty,
        isTrue,
      );
    });
  });

  group('FogGeometry cache', () {
    test('builds each region once and reuses the path', () {
      final geometry = FogGeometry(projection: _projection);

      final first = geometry.add(_square());
      final second = geometry.add(_square());

      expect(identical(first, second), isTrue);
      expect(geometry.length, 1);
    });

    test('culls by precomputed bounds', () {
      final geometry = FogGeometry(projection: _projection)
        ..add(_square())
        ..add(_farSquare());

      final nearBounds = geometry.boundsFor('square')!;

      expect(geometry.pathsIntersecting(nearBounds), hasLength(1));
      expect(
        geometry.pathsIntersecting(const Rect.fromLTWH(-1e9, -1e9, 2e9, 2e9)),
        hasLength(2),
      );
    });

    test('excludes dissolving regions from the permanent hole pass', () {
      // A region mid-dissipation clears on its own animated ramp. Letting it
      // through here would punch the hole instantly and cancel the effect.
      final geometry = FogGeometry(projection: _projection)..add(_square());

      final everywhere = const Rect.fromLTWH(-1e9, -1e9, 2e9, 2e9);

      expect(geometry.pathsIntersecting(everywhere), hasLength(1));
      expect(
        geometry.pathsIntersecting(everywhere, excluding: <String>{'square'}),
        isEmpty,
      );
    });

    test('remove and clear drop cached bounds too', () {
      final geometry = FogGeometry(projection: _projection)
        ..add(_square())
        ..add(_farSquare());

      geometry.remove('square');
      expect(geometry.boundsFor('square'), isNull);
      expect(geometry.length, 1);

      geometry.clear();
      expect(geometry.length, 0);
      expect(geometry.boundsFor('far'), isNull);
    });
  });
}

Offset _worldCentreOfSquare() => _projection.latLngToWorld(-37.85, 144.95);

RegionPolygon _square() {
  return const RegionPolygon(
    id: 'square',
    name: 'Square',
    areaSquareMetres: 1000,
    geometry: <String, dynamic>{
      'type': 'Polygon',
      'coordinates': <dynamic>[
        <dynamic>[
          <double>[144.90, -37.90],
          <double>[145.00, -37.90],
          <double>[145.00, -37.80],
          <double>[144.90, -37.80],
          <double>[144.90, -37.90],
        ],
      ],
    },
  );
}

RegionPolygon _farSquare() {
  return const RegionPolygon(
    id: 'far',
    name: 'Far',
    areaSquareMetres: 1000,
    geometry: <String, dynamic>{
      'type': 'Polygon',
      'coordinates': <dynamic>[
        <dynamic>[
          <double>[146.90, -36.90],
          <double>[147.00, -36.90],
          <double>[147.00, -36.80],
          <double>[146.90, -36.80],
          <double>[146.90, -36.90],
        ],
      ],
    },
  );
}

RegionPolygon _twoSquares() {
  return const RegionPolygon(
    id: 'multi',
    name: 'Multi',
    areaSquareMetres: 2000,
    geometry: <String, dynamic>{
      'type': 'MultiPolygon',
      'coordinates': <dynamic>[
        <dynamic>[
          <dynamic>[
            <double>[144.90, -37.90],
            <double>[145.00, -37.90],
            <double>[145.00, -37.80],
            <double>[144.90, -37.80],
            <double>[144.90, -37.90],
          ],
        ],
        <dynamic>[
          <dynamic>[
            <double>[145.10, -37.70],
            <double>[145.20, -37.70],
            <double>[145.20, -37.60],
            <double>[145.10, -37.60],
            <double>[145.10, -37.70],
          ],
        ],
      ],
    },
  );
}
