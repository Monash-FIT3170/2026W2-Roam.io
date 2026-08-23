/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 22 August 2026
 * Description:
 *   Tests static Journey map snapshot polygon loading for completion previews.
 */

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/activity_feed/domain/activity_route.dart';
import 'package:roam_io/features/map/data/journey_map_snapshot_service.dart';
import 'package:roam_io/features/map/data/region_polygon.dart';
import 'package:roam_io/features/map/data/region_polygon_cache.dart';
import 'package:roam_io/features/map/data/region_service.dart';

void main() {
  test(
    'loads route bounds and reuses cache styling for fog and visited tiles',
    () async {
      final regionService = _FakeRegionService([
        _region(id: 'visited-tile'),
        _region(id: 'fog-tile'),
      ]);
      final service = JourneyMapSnapshotService(
        regionService: regionService,
        regionPolygonCache: RegionPolygonCache(),
      );
      final route = ActivityRoute.fromPoints(const [
        LatLng(-37.8136, 144.9631),
        LatLng(-37.8118, 144.9690),
      ])!;

      final overlay = await service.loadRouteSnapshotOverlay(
        route: route,
        visitedRegionIds: const {'visited-tile'},
        currentRegionId: null,
      );

      expect(
        regionService.requestedSouth,
        lessThan(route.bounds.southwest.latitude),
      );
      expect(
        regionService.requestedWest,
        lessThan(route.bounds.southwest.longitude),
      );
      expect(
        regionService.requestedNorth,
        greaterThan(route.bounds.northeast.latitude),
      );
      expect(
        regionService.requestedEast,
        greaterThan(route.bounds.northeast.longitude),
      );
      expect(overlay.tilePolygons, hasLength(2));
      expect(overlay.loadedBounds, isNotNull);
      expect(
        overlay.tilePolygons
            .firstWhere((polygon) => polygon.polygonId.value == 'visited-tile')
            .fillColor,
        const Color(0x30FFFFFF),
      );
      expect(
        overlay.tilePolygons
            .firstWhere((polygon) => polygon.polygonId.value == 'visited-tile')
            .zIndex,
        5,
      );
      expect(
        overlay.tilePolygons
            .firstWhere((polygon) => polygon.polygonId.value == 'fog-tile')
            .fillColor,
        const Color(0xCC000000),
      );
      expect(
        overlay.polygonsForVisibleBounds(route.bounds),
        overlay.tilePolygons,
      );
    },
  );

  test(
    'empty overlay renders no fake fog when no region polygons are loaded',
    () async {
      final service = JourneyMapSnapshotService(
        regionService: _FakeRegionService(const []),
        regionPolygonCache: RegionPolygonCache(),
      );
      final route = ActivityRoute.fromPoints(const [
        LatLng(-37.8136, 144.9631),
        LatLng(-37.8118, 144.9690),
      ])!;

      final overlay = await service.loadRouteSnapshotOverlay(
        route: route,
        visitedRegionIds: const {'visited-but-not-loaded'},
        currentRegionId: null,
      );

      expect(overlay.tilePolygons, isEmpty);
      final renderedPolygons = overlay.polygonsForVisibleBounds(route.bounds);
      expect(renderedPolygons, isEmpty);
    },
  );

  test('loads unvisited fog even when no regions have been visited', () async {
    final service = JourneyMapSnapshotService(
      regionService: _FakeRegionService([_region(id: 'fog-tile')]),
      regionPolygonCache: RegionPolygonCache(),
    );
    final route = ActivityRoute.fromPoints(const [
      LatLng(-37.8136, 144.9631),
      LatLng(-37.8118, 144.9690),
    ])!;

    final overlay = await service.loadRouteSnapshotOverlay(
      route: route,
      visitedRegionIds: const <String>{},
      currentRegionId: null,
    );

    expect(overlay.tilePolygons, hasLength(1));
    expect(overlay.tilePolygons.single.polygonId.value, 'fog-tile');
    expect(overlay.tilePolygons.single.fillColor, const Color(0xCC000000));
  });

  test('uses fitted viewport bounds when provided', () async {
    final regionService = _FakeRegionService([_region(id: 'fog-tile')]);
    final service = JourneyMapSnapshotService(
      regionService: regionService,
      regionPolygonCache: RegionPolygonCache(),
    );
    final route = ActivityRoute.fromPoints(const [
      LatLng(-37.8136, 144.9631),
      LatLng(-37.8118, 144.9690),
    ])!;
    final viewportBounds = LatLngBounds(
      southwest: const LatLng(-37.82, 144.95),
      northeast: const LatLng(-37.80, 144.98),
    );

    final overlay = await service.loadRouteSnapshotOverlay(
      route: route,
      visitedRegionIds: const <String>{},
      currentRegionId: null,
      viewportBounds: viewportBounds,
    );

    expect(
      regionService.requestedSouth,
      lessThan(viewportBounds.southwest.latitude),
    );
    expect(
      regionService.requestedWest,
      lessThan(viewportBounds.southwest.longitude),
    );
    expect(
      regionService.requestedNorth,
      greaterThan(viewportBounds.northeast.latitude),
    );
    expect(
      regionService.requestedEast,
      greaterThan(viewportBounds.northeast.longitude),
    );
    expect(overlay.covers(viewportBounds), isTrue);
  });
}

class _FakeRegionService extends RegionService {
  _FakeRegionService(this.regions);

  final List<RegionPolygon> regions;
  late final double requestedSouth;
  late final double requestedWest;
  late final double requestedNorth;
  late final double requestedEast;

  @override
  Future<List<RegionPolygon>> getRegionsForViewport({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    requestedSouth = south;
    requestedWest = west;
    requestedNorth = north;
    requestedEast = east;
    return regions;
  }
}

RegionPolygon _region({required String id}) {
  return RegionPolygon(
    id: id,
    name: id,
    areaSquareMetres: 1000,
    geometry: const <String, dynamic>{
      'type': 'Polygon',
      'coordinates': <dynamic>[
        <dynamic>[
          <double>[144.9630, -37.8140],
          <double>[144.9700, -37.8140],
          <double>[144.9700, -37.8110],
          <double>[144.9630, -37.8110],
          <double>[144.9630, -37.8140],
        ],
      ],
    },
  );
}
