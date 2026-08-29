/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 28 August 2026
 * Description:
 *   Builds the static fog for a completed Journey map preview without starting
 *   live location tracking.
 */

import 'dart:ui';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../activity_feed/domain/activity_route.dart';
import 'map_viewport_policy.dart';
import 'region_polygon.dart';
import 'region_service.dart';

/// Builds a static fog/unlocked-tile overlay around a completed Journey route.
class JourneyMapSnapshotService {
  JourneyMapSnapshotService({
    RegionService? regionService,
    MapViewportPolicy? viewportPolicy,
  }) : _regionService = regionService ?? RegionService(),
       _viewportPolicy = viewportPolicy ?? MapViewportPolicy();

  /// Fog fill for a surface with no animated cloud layer above it. A Journey
  /// preview is a plain GoogleMap, so the fog has to carry its own colour.
  static const _fogFill = Color(0xCC000000);

  /// Share of the fogged span kept between the sheet's edge and its holes.
  static const _sheetMarginRatio = 0.25;

  final RegionService _regionService;
  final MapViewportPolicy _viewportPolicy;

  Future<JourneyMapSnapshotOverlay> loadRouteSnapshotOverlay({
    required ActivityRoute route,
    required Set<String> visitedRegionIds,
    String? currentRegionId,
    LatLngBounds? viewportBounds,
  }) async {
    final bounds = _viewportPolicy.expandSa1Bounds(
      viewportBounds ?? route.bounds,
    );
    final exploredRegionIds = <String>{
      ...visitedRegionIds,
      if (currentRegionId != null && currentRegionId.isNotEmpty)
        currentRegionId,
    };

    // Only explored ground is drawn, as holes in the fog. Fetching the
    // unexplored tiles too made the request grow with the length of the
    // journey, which is what left long journeys showing bare basemap.
    final regions = exploredRegionIds.isEmpty
        ? const <RegionPolygon>[]
        : await _regionService.getRegionsForViewport(
            south: bounds.southwest.latitude,
            west: bounds.southwest.longitude,
            north: bounds.northeast.latitude,
            east: bounds.northeast.longitude,
            regionIds: exploredRegionIds,
          );

    final clearedRings = <List<LatLng>>[];
    for (final region in regions) {
      // Backends that predate the id filter answer with the whole viewport.
      if (!exploredRegionIds.contains(region.id)) continue;
      for (final polygon in region.toGooglePolygons()) {
        if (polygon.points.length < 3) continue;
        clearedRings.add(polygon.points);
      }
    }

    return JourneyMapSnapshotOverlay(
      loadedBounds: bounds,
      tilePolygons: {_fogSheet(bounds: bounds, clearedRings: clearedRings)},
    );
  }

  /// One polygon covering the frame, with explored ground punched out of it.
  Polygon _fogSheet({
    required LatLngBounds bounds,
    required List<List<LatLng>> clearedRings,
  }) {
    final sheet = _sheetBounds(bounds, clearedRings);

    return Polygon(
      polygonId: const PolygonId('journey-fog'),
      points: <LatLng>[
        sheet.southwest,
        LatLng(sheet.northeast.latitude, sheet.southwest.longitude),
        sheet.northeast,
        LatLng(sheet.southwest.latitude, sheet.northeast.longitude),
      ],
      holes: clearedRings,
      fillColor: _fogFill,
      strokeColor: const Color(0x00000000),
      strokeWidth: 0,
      zIndex: 5,
    );
  }

  /// The fogged rectangle, stretched past every hole it carries.
  ///
  /// A region can run well past the framed route, and a hole crossing the
  /// sheet's own edge does not render as cleared ground.
  LatLngBounds _sheetBounds(
    LatLngBounds bounds,
    List<List<LatLng>> clearedRings,
  ) {
    var south = bounds.southwest.latitude;
    var north = bounds.northeast.latitude;
    var west = bounds.southwest.longitude;
    var east = bounds.northeast.longitude;

    for (final ring in clearedRings) {
      for (final point in ring) {
        south = point.latitude < south ? point.latitude : south;
        north = point.latitude > north ? point.latitude : north;
        west = point.longitude < west ? point.longitude : west;
        east = point.longitude > east ? point.longitude : east;
      }
    }

    final latMargin = (north - south).abs() * _sheetMarginRatio;
    final lngMargin = (east - west).abs() * _sheetMarginRatio;

    return LatLngBounds(
      southwest: LatLng(
        (south - latMargin).clamp(-90.0, 90.0),
        (west - lngMargin).clamp(-180.0, 180.0),
      ),
      northeast: LatLng(
        (north + latMargin).clamp(-90.0, 90.0),
        (east + lngMargin).clamp(-180.0, 180.0),
      ),
    );
  }
}

/// Static map overlay data for completed Journey previews.
class JourneyMapSnapshotOverlay {
  const JourneyMapSnapshotOverlay({
    this.loadedBounds,
    required this.tilePolygons,
  });

  static const empty = JourneyMapSnapshotOverlay(
    loadedBounds: null,
    tilePolygons: <Polygon>{},
  );

  final LatLngBounds? loadedBounds;
  final Set<Polygon> tilePolygons;

  Set<Polygon> polygonsForVisibleBounds(LatLngBounds bounds) {
    return tilePolygons;
  }

  bool covers(LatLngBounds bounds) {
    final loaded = loadedBounds;
    if (loaded == null) return false;
    return bounds.southwest.latitude >= loaded.southwest.latitude &&
        bounds.southwest.longitude >= loaded.southwest.longitude &&
        bounds.northeast.latitude <= loaded.northeast.latitude &&
        bounds.northeast.longitude <= loaded.northeast.longitude;
  }
}
