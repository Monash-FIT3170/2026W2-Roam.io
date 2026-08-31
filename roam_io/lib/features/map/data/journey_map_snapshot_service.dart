/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 29 August 2026
 * Description:
 *   Builds the static fog for a completed Journey map preview without starting
 *   live location tracking.
 */

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

    // Backends that predate the id filter answer with the whole viewport, so
    // the ids are checked again here rather than trusted.
    final clearedRegions = <RegionPolygon>[
      for (final region in regions)
        if (exploredRegionIds.contains(region.id)) region,
    ];

    return JourneyMapSnapshotOverlay(
      loadedBounds: bounds,
      clearedRegions: clearedRegions,
    );
  }
}

/// Static map overlay data for completed Journey previews.
///
/// Carries the explored ground rather than a fog shape: the fog itself is the
/// cloud field drawn over the map, and what varies per journey is the holes cut
/// in it.
class JourneyMapSnapshotOverlay {
  const JourneyMapSnapshotOverlay({
    this.loadedBounds,
    required this.clearedRegions,
  });

  static const empty = JourneyMapSnapshotOverlay(
    loadedBounds: null,
    clearedRegions: <RegionPolygon>[],
  );

  /// The frame this overlay was loaded for, or null when nothing loaded.
  ///
  /// Null keeps the map bare instead of fogging it: a failed load must not hide
  /// the journey behind cloud it has no holes for.
  final LatLngBounds? loadedBounds;

  /// Regions the traveller had explored, cleared out of the fog.
  final List<RegionPolygon> clearedRegions;

  bool covers(LatLngBounds bounds) {
    final loaded = loadedBounds;
    if (loaded == null) return false;
    return bounds.southwest.latitude >= loaded.southwest.latitude &&
        bounds.southwest.longitude >= loaded.southwest.longitude &&
        bounds.northeast.latitude <= loaded.northeast.latitude &&
        bounds.northeast.longitude <= loaded.northeast.longitude;
  }
}
