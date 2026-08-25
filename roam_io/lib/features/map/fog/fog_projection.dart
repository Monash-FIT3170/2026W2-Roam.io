/*
 * Description:
 *   Web Mercator projection used by the fog overlay to place world geometry on
 *   screen without round-tripping through the Google Maps platform channel.
 *
 *   GoogleMapController.getScreenCoordinate is asynchronous, so it cannot be
 *   used per-vertex per-frame. These pure functions reproduce the same
 *   projection Google Maps uses, driven by the CameraPosition the map already
 *   reports through onCameraMove.
 *
 *   Coordinates are expressed in "world pixels" at [referenceZoom] relative to
 *   a session anchor rather than at zoom 0. Zoom-0 coordinates span only
 *   0..256, and scaling those by 2^20 at maximum zoom exhausts Float32
 *   precision inside ui.Path, which shows up as visible vertex jitter. Anchored
 *   reference-zoom coordinates stay in the low thousands and stay exact.
 */

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Tile size in logical pixels used by Google Maps at zoom 0.
const double kTileSize = 256.0;

/// Zoom level that world coordinates are expressed in.
///
/// Matches the map's default zoom so on-screen scale is 1:1 in the common case.
const double kReferenceZoom = 16.0;

/// Web Mercator clamps latitude to this value; beyond it the projection
/// diverges to infinity.
const double kMaxMercatorLatitude = 85.05112878;

/// Projects between geographic coordinates and fog world space.
///
/// [anchor] fixes the origin of world space. All returned offsets are relative
/// to it, which is what keeps path coordinates small enough to stay precise.
class FogProjection {
  const FogProjection({required this.anchor});

  final LatLng anchor;

  /// Scale factor from reference-zoom world pixels to screen pixels.
  static double scaleForZoom(double zoom) {
    return math.pow(2.0, zoom - kReferenceZoom).toDouble();
  }

  /// Converts a geographic coordinate to anchored world pixels.
  Offset latLngToWorld(double latitude, double longitude) {
    final absolute = _absoluteWorld(latitude, longitude);
    final origin = _absoluteWorld(anchor.latitude, anchor.longitude);
    return absolute - origin;
  }

  /// Converts anchored world pixels back to a geographic coordinate.
  LatLng worldToLatLng(Offset world) {
    final origin = _absoluteWorld(anchor.latitude, anchor.longitude);
    final absolute = world + origin;
    final worldSize = kTileSize * math.pow(2.0, kReferenceZoom).toDouble();

    final longitude = absolute.dx / worldSize * 360.0 - 180.0;
    final n = math.pi * (1.0 - 2.0 * absolute.dy / worldSize);
    final latitude = _degrees(math.atan(_sinh(n)));

    return LatLng(latitude, longitude);
  }

  /// Builds the world-space to screen-space transform for a camera and canvas.
  ///
  /// The camera target maps to the centre of [size]. Bearing is applied as a
  /// rotation; tilt is deliberately unsupported and must be disabled on the map
  /// widget, because Google Maps does not expose the field of view needed to
  /// reproduce its perspective projection.
  Matrix4 matrixFor({required CameraPosition camera, required Size size}) {
    final scale = scaleForZoom(camera.zoom);
    final target = latLngToWorld(
      camera.target.latitude,
      camera.target.longitude,
    );

    final matrix = Matrix4.identity()
      ..translateByDouble(size.width / 2.0, size.height / 2.0, 0.0, 1.0);

    if (camera.bearing != 0.0) {
      matrix.rotateZ(-_radians(camera.bearing));
    }

    return matrix
      ..scaleByDouble(scale, scale, 1.0, 1.0)
      ..translateByDouble(-target.dx, -target.dy, 0.0, 1.0);
  }

  /// World-space rectangle currently visible for a camera and canvas.
  ///
  /// Padded by the diagonal when the camera is rotated so the caller never
  /// misses geometry that rotates into view at the corners.
  Rect visibleWorldBounds({
    required CameraPosition camera,
    required Size size,
    double paddingFactor = 1.0,
  }) {
    final scale = scaleForZoom(camera.zoom);
    final target = latLngToWorld(
      camera.target.latitude,
      camera.target.longitude,
    );

    var halfWidth = size.width / 2.0 / scale;
    var halfHeight = size.height / 2.0 / scale;

    if (camera.bearing != 0.0) {
      // A rotated viewport is contained by the circle through its corners.
      final radius = math.sqrt(halfWidth * halfWidth + halfHeight * halfHeight);
      halfWidth = radius;
      halfHeight = radius;
    }

    return Rect.fromLTRB(
      target.dx - halfWidth * paddingFactor,
      target.dy - halfHeight * paddingFactor,
      target.dx + halfWidth * paddingFactor,
      target.dy + halfHeight * paddingFactor,
    );
  }

  /// Absolute (unanchored) world pixels at [kReferenceZoom].
  static Offset _absoluteWorld(double latitude, double longitude) {
    final worldSize = kTileSize * math.pow(2.0, kReferenceZoom).toDouble();
    final clampedLatitude = latitude.clamp(
      -kMaxMercatorLatitude,
      kMaxMercatorLatitude,
    );
    final latitudeRadians = _radians(clampedLatitude);

    final x = (longitude + 180.0) / 360.0 * worldSize;
    final y =
        (0.5 -
            math.log(math.tan(math.pi / 4.0 + latitudeRadians / 2.0)) /
                (2.0 * math.pi)) *
        worldSize;

    return Offset(x, y);
  }

  static double _radians(double degrees) => degrees * math.pi / 180.0;

  static double _degrees(double radians) => radians * 180.0 / math.pi;

  static double _sinh(double value) =>
      (math.exp(value) - math.exp(-value)) / 2.0;
}
