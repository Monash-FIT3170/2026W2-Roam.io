import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/map/fog/fog_projection.dart';

/// Federation Square, Melbourne — inside the SA1 coverage the app ships with.
const LatLng _melbourne = LatLng(-37.8136, 144.9631);

void main() {
  group('FogProjection', () {
    const projection = FogProjection(anchor: _melbourne);

    test('anchor projects to the world origin', () {
      final world = projection.latLngToWorld(
        _melbourne.latitude,
        _melbourne.longitude,
      );

      expect(world.dx, closeTo(0.0, 1e-9));
      expect(world.dy, closeTo(0.0, 1e-9));
    });

    test('round-trips geographic coordinates', () {
      const samples = <LatLng>[
        _melbourne,
        LatLng(-37.7, 145.1),
        LatLng(-38.0, 144.8),
        LatLng(51.5074, -0.1278),
        LatLng(0.0, 0.0),
      ];

      for (final sample in samples) {
        final world = projection.latLngToWorld(
          sample.latitude,
          sample.longitude,
        );
        final result = projection.worldToLatLng(world);

        expect(
          result.latitude,
          closeTo(sample.latitude, 1e-9),
          reason: 'latitude for $sample',
        );
        expect(
          result.longitude,
          closeTo(sample.longitude, 1e-9),
          reason: 'longitude for $sample',
        );
      }
    });

    test('matches the documented Web Mercator tile formula', () {
      // Google's projection places the anchor at a known absolute world pixel
      // for a given zoom. Verifying against the published formula rather than
      // against our own round-trip catches a sign or scale error that a
      // self-consistent implementation would hide.
      const origin = FogProjection(anchor: LatLng(0.0, -180.0));
      final world = origin.latLngToWorld(0.0, 0.0);
      final worldSize = kTileSize * math.pow(2.0, kReferenceZoom);

      expect(world.dx, closeTo(worldSize / 2.0, 1e-6));
      expect(world.dy, closeTo(0.0, 1e-6));
    });

    test('east is +x and north is -y', () {
      final east = projection.latLngToWorld(
        _melbourne.latitude,
        _melbourne.longitude + 0.05,
      );
      final north = projection.latLngToWorld(
        _melbourne.latitude + 0.05,
        _melbourne.longitude,
      );

      expect(east.dx, greaterThan(0));
      expect(north.dy, lessThan(0));
    });

    test('clamps beyond the Mercator latitude limit instead of diverging', () {
      final world = projection.latLngToWorld(89.9, 0.0);

      expect(world.dy.isFinite, isTrue);
    });

    test('scale doubles per zoom level and is 1 at the reference zoom', () {
      expect(FogProjection.scaleForZoom(kReferenceZoom), closeTo(1.0, 1e-12));
      expect(
        FogProjection.scaleForZoom(kReferenceZoom + 1),
        closeTo(2.0, 1e-12),
      );
      expect(
        FogProjection.scaleForZoom(kReferenceZoom - 2),
        closeTo(0.25, 1e-12),
      );
    });

    group('matrixFor', () {
      const size = Size(400, 800);

      test('places the camera target at the centre of the canvas', () {
        const camera = CameraPosition(target: _melbourne, zoom: kReferenceZoom);
        final matrix = projection.matrixFor(camera: camera, size: size);

        final screen = MatrixUtils.transformPoint(matrix, Offset.zero);

        expect(screen.dx, closeTo(size.width / 2, 1e-6));
        expect(screen.dy, closeTo(size.height / 2, 1e-6));
      });

      test('scales world units by the zoom factor', () {
        const camera = CameraPosition(
          target: _melbourne,
          zoom: kReferenceZoom + 1,
        );
        final matrix = projection.matrixFor(camera: camera, size: size);

        final screen = MatrixUtils.transformPoint(
          matrix,
          const Offset(10.0, 0.0),
        );

        // One zoom level in means 10 world units cover 20 logical pixels.
        expect(screen.dx - size.width / 2, closeTo(20.0, 1e-6));
      });

      test('rotates the world opposite the camera bearing', () {
        // A bearing of 90 turns the map clockwise, so ground that lay to the
        // east must appear at the top of the screen.
        const camera = CameraPosition(
          target: _melbourne,
          zoom: kReferenceZoom,
          bearing: 90.0,
        );
        final matrix = projection.matrixFor(camera: camera, size: size);

        final screen = MatrixUtils.transformPoint(
          matrix,
          const Offset(10.0, 0.0),
        );

        expect(screen.dx - size.width / 2, closeTo(0.0, 1e-6));
        expect(screen.dy - size.height / 2, closeTo(-10.0, 1e-6));
      });
    });

    group('visibleWorldBounds', () {
      const size = Size(400, 800);

      test('covers exactly the viewport when unrotated', () {
        const camera = CameraPosition(target: _melbourne, zoom: kReferenceZoom);
        final bounds = projection.visibleWorldBounds(
          camera: camera,
          size: size,
        );

        expect(bounds.width, closeTo(size.width, 1e-6));
        expect(bounds.height, closeTo(size.height, 1e-6));
        expect(bounds.center.dx, closeTo(0.0, 1e-6));
        expect(bounds.center.dy, closeTo(0.0, 1e-6));
      });

      test('expands to the corner radius when rotated', () {
        // A rotated viewport sweeps its corners through the bounds, so culling
        // against the unrotated rect would drop geometry that is on screen.
        const camera = CameraPosition(
          target: _melbourne,
          zoom: kReferenceZoom,
          bearing: 45.0,
        );
        final bounds = projection.visibleWorldBounds(
          camera: camera,
          size: size,
        );

        final expected =
            math.sqrt(
              math.pow(size.width / 2, 2) + math.pow(size.height / 2, 2),
            ) *
            2;

        expect(bounds.width, closeTo(expected, 1e-6));
        expect(bounds.height, closeTo(expected, 1e-6));
      });

      test('shrinks in world units as the user zooms in', () {
        const near = CameraPosition(
          target: _melbourne,
          zoom: kReferenceZoom + 2,
        );
        const far = CameraPosition(target: _melbourne, zoom: kReferenceZoom);

        final nearBounds = projection.visibleWorldBounds(
          camera: near,
          size: size,
        );
        final farBounds = projection.visibleWorldBounds(
          camera: far,
          size: size,
        );

        expect(nearBounds.width, closeTo(farBounds.width / 4, 1e-6));
      });
    });

    test('keeps coordinates small enough to stay precise at max zoom', () {
      // The reason world space is anchored at all: zoom-0 coordinates scaled to
      // zoom 20 exhaust Float32 precision inside ui.Path and show up as vertex
      // jitter. Anything within a city of the anchor must stay far below the
      // ~16.7M mark where Float32 loses integer precision.
      final corner = projection.latLngToWorld(-37.5, 145.5);
      final scaled = corner * FogProjection.scaleForZoom(20.0);

      expect(scaled.dx.abs(), lessThan(1 << 22));
      expect(scaled.dy.abs(), lessThan(1 << 22));
    });
  });
}
