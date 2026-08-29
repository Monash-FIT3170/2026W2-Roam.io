/*
 * Description:
 *   Converts region GeoJSON into world-space ui.Path objects for the fog
 *   overlay, and caches them so paths are built once per region rather than
 *   once per frame.
 *
 *   Unlike RegionPolygon.toGooglePolygons, this preserves MultiPolygon inner
 *   rings. Google Maps polygons never populated `holes`, so a donut-shaped
 *   region rendered as a solid blob and nobody noticed. The fog punches holes
 *   for explored ground, so dropping an inner ring here would incorrectly clear
 *   territory the user has not visited.
 */

import 'dart:ui';

import '../data/region_polygon.dart';
import 'fog_projection.dart';

/// Builds and caches world-space fog geometry for visited regions.
///
/// Paths are stored in anchored reference-zoom world pixels (see
/// [FogProjection]) so the painter only has to apply a transform per frame
/// instead of rebuilding geometry.
class FogGeometry {
  FogGeometry({required this.projection});

  final FogProjection projection;

  final Map<String, Path> _pathsByRegionId = <String, Path>{};
  final Map<String, Rect> _boundsByRegionId = <String, Rect>{};

  /// World-space paths for every region currently held.
  Iterable<Path> get paths => _pathsByRegionId.values;

  /// Region ids currently held.
  Iterable<String> get regionIds => _pathsByRegionId.keys;

  int get length => _pathsByRegionId.length;

  bool contains(String regionId) => _pathsByRegionId.containsKey(regionId);

  Path? pathFor(String regionId) => _pathsByRegionId[regionId];

  Rect? boundsFor(String regionId) => _boundsByRegionId[regionId];

  /// Builds and caches the path for [region] unless it is already present.
  ///
  /// Returns the cached path when the region is already known, so repeated
  /// viewport loads of the same region cost nothing.
  Path add(RegionPolygon region) {
    final existing = _pathsByRegionId[region.id];
    if (existing != null) return existing;

    final path = buildPath(region, projection);
    _pathsByRegionId[region.id] = path;
    _boundsByRegionId[region.id] = path.getBounds();
    return path;
  }

  void remove(String regionId) {
    _pathsByRegionId.remove(regionId);
    _boundsByRegionId.remove(regionId);
  }

  void clear() {
    _pathsByRegionId.clear();
    _boundsByRegionId.clear();
  }

  /// Paths whose bounds intersect [worldBounds].
  ///
  /// Bounds are precomputed at insert time, so culling is a cheap rectangle
  /// test rather than a path traversal.
  ///
  /// [excluding] skips regions that are mid-dissipation. Those are cleared on
  /// their own animated ramp instead, and letting them through here would punch
  /// the hole instantly and cancel the effect.
  List<Path> pathsIntersecting(
    Rect worldBounds, {
    Set<String> excluding = const <String>{},
  }) {
    final visible = <Path>[];

    for (final entry in _pathsByRegionId.entries) {
      if (excluding.contains(entry.key)) continue;

      final bounds = _boundsByRegionId[entry.key];
      if (bounds != null && bounds.overlaps(worldBounds)) {
        visible.add(entry.value);
      }
    }

    return visible;
  }

  /// Converts a region's GeoJSON into a single world-space path.
  ///
  /// Uses [PathFillType.evenOdd] so inner rings subtract from their outer ring,
  /// which is what makes donut-shaped regions clear correctly.
  static Path buildPath(RegionPolygon region, FogProjection projection) {
    final path = Path()..fillType = PathFillType.evenOdd;
    final type = region.geometry['type'] as String?;
    final coordinates = region.geometry['coordinates'];

    if (coordinates is! List) return path;

    switch (type) {
      case 'Polygon':
        _addPolygon(path, coordinates, projection);
      case 'MultiPolygon':
        for (final polygon in coordinates) {
          if (polygon is List) {
            _addPolygon(path, polygon, projection);
          }
        }
      default:
        // Unknown geometry contributes nothing rather than throwing. A bad
        // region should leave that patch fogged, not crash the map.
        break;
    }

    return path;
  }

  /// Adds every ring of one GeoJSON polygon, outer ring first.
  static void _addPolygon(
    Path path,
    List<dynamic> rings,
    FogProjection projection,
  ) {
    for (final ring in rings) {
      if (ring is List) {
        _addRing(path, ring, projection);
      }
    }
  }

  static void _addRing(
    Path path,
    List<dynamic> ring,
    FogProjection projection,
  ) {
    var isFirst = true;

    for (final coordinate in ring) {
      if (coordinate is! List || coordinate.length < 2) continue;

      final longitude = (coordinate[0] as num).toDouble();
      final latitude = (coordinate[1] as num).toDouble();
      final point = projection.latLngToWorld(latitude, longitude);

      if (isFirst) {
        path.moveTo(point.dx, point.dy);
        isFirst = false;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    if (!isFirst) {
      path.close();
    }
  }
}
