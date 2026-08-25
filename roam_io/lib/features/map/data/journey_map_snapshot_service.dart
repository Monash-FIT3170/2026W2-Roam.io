/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 22 August 2026
 * Description:
 *   Loads static Roam.io exploration polygons for completed Journey map
 *   previews without starting live location tracking.
 */

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../activity_feed/domain/activity_route.dart';
import 'map_viewport_policy.dart';
import 'region_polygon_cache.dart';
import 'region_service.dart';

/// Builds a static fog/unlocked-tile overlay around a completed Journey route.
class JourneyMapSnapshotService {
  JourneyMapSnapshotService({
    RegionService? regionService,
    RegionPolygonCache? regionPolygonCache,
    MapViewportPolicy? viewportPolicy,
  }) : _regionService = regionService ?? RegionService(),
       // Static fog styling: a Journey preview is a plain GoogleMap with no
       // FogOverlay above it, so unexplored ground has to carry its own fill or
       // the preview shows bare basemap where the fog should be.
       _regionPolygonCache =
           regionPolygonCache ?? RegionPolygonCache.staticFog(),
       _viewportPolicy = viewportPolicy ?? MapViewportPolicy();

  final RegionService _regionService;
  final RegionPolygonCache _regionPolygonCache;
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
    final regions = await _regionService.getRegionsForViewport(
      south: bounds.southwest.latitude,
      west: bounds.southwest.longitude,
      north: bounds.northeast.latitude,
      east: bounds.northeast.longitude,
    );

    for (final region in regions) {
      _regionPolygonCache.cacheRegion(
        region: region,
        isVisited: visitedRegionIds.contains(region.id),
        isCurrentRegion: currentRegionId == region.id,
        onRegionTapped: (_, _) {},
      );
    }

    final tilePolygons = _regionPolygonCache.polygonsForDisplay(
      showUnvisitedRegions: true,
      visitedRegionIds: visitedRegionIds,
      currentRegionId: currentRegionId,
    );

    return JourneyMapSnapshotOverlay(
      loadedBounds: bounds,
      tilePolygons: tilePolygons
          .map((polygon) => polygon.copyWith(zIndexParam: 5))
          .toSet(),
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
