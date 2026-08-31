/*
 * Description:
 *   The cloud fog on a map that is not being explored: journey previews, the
 *   summary sheet, and the picture captured from them.
 *
 *   It is the same wash, the same sprite field and the same feathered holes the
 *   live map draws — the whole point is that a shared journey looks like the map
 *   it was recorded on — with the parts that only make sense while travelling
 *   removed. There is no ticker: one frozen instant is what keeps a scrolling
 *   feed from animating a cloud field per card, and what makes a capture of the
 *   same journey come out the same twice.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../data/region_polygon.dart';
import 'fog_atlas.dart';
import 'fog_field.dart';
import 'fog_geometry.dart';
import 'fog_painter.dart';
import 'fog_projection.dart';

/// Cloud fog for a still map, with explored regions cleared out of it.
class StaticFog {
  StaticFog._(this.projection, this.geometry)
    : _field = FogField(projection: projection);

  /// Fog anchored at [anchor] — normally the framed route's centre — with
  /// [clearedRegions] punched out of it.
  factory StaticFog({
    required LatLng anchor,
    required Iterable<RegionPolygon> clearedRegions,
  }) {
    final projection = FogProjection(anchor: anchor);
    final geometry = FogGeometry(projection: projection);
    for (final region in clearedRegions) {
      geometry.add(region);
    }
    return StaticFog._(projection, geometry);
  }

  final FogProjection projection;
  final FogGeometry geometry;
  final FogField _field;

  /// The regions cleared out of this fog.
  Iterable<String> get clearedRegionIds => geometry.regionIds;

  /// The camera target of [bounds], which for an untilted map is the position
  /// the map is centred on.
  ///
  /// Latitudes are averaged in Mercator space rather than in degrees, because
  /// the visible region is a rectangle on the projected map, not on the globe.
  LatLng centreOf(LatLngBounds bounds) {
    final southwest = projection.latLngToWorld(
      bounds.southwest.latitude,
      bounds.southwest.longitude,
    );
    final northeast = projection.latLngToWorld(
      bounds.northeast.latitude,
      bounds.northeast.longitude,
    );
    return projection.worldToLatLng((southwest + northeast) / 2.0);
  }

  /// One still frame of this fog, for a map framed by [camera].
  FogPainter painterFor({
    required CameraPosition camera,
    required FogAtlas atlas,
    required bool isNight,
  }) {
    return FogPainter(
      projection: projection,
      geometry: geometry,
      field: _field,
      camera: camera,
      elapsed: Duration.zero,
      dissolves: const [],
      atlas: atlas,
      userSpeedMetresPerSecond: 0.0,
      isNight: isNight,
    );
  }
}

/// Draws [fog] over the map it belongs to.
///
/// Sits directly above the map in a [Stack]. The camera arrives as a listenable
/// so a gesture repaints the clouds alone rather than rebuilding the map, its
/// markers and its polylines sixty times a second.
class StaticFogOverlay extends StatelessWidget {
  const StaticFogOverlay({
    super.key,
    required this.fog,
    required this.atlas,
    required this.camera,
    required this.isNight,
  });

  final StaticFog fog;

  /// Cloud artwork, null until it has finished baking.
  final FogAtlas? atlas;

  final ValueListenable<CameraPosition?> camera;
  final bool isNight;

  @override
  Widget build(BuildContext context) {
    final atlas = this.atlas;
    if (atlas == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: RepaintBoundary(
        child: ValueListenableBuilder<CameraPosition?>(
          valueListenable: camera,
          builder: (context, camera, _) {
            // Until the map reports where it settled there is nothing to align
            // the clouds to, and fog drawn against a guessed camera would clear
            // the wrong ground.
            if (camera == null) return const SizedBox.shrink();

            return CustomPaint(
              size: Size.infinite,
              painter: fog.painterFor(
                camera: camera,
                atlas: atlas,
                isNight: isNight,
              ),
            );
          },
        ),
      ),
    );
  }
}
