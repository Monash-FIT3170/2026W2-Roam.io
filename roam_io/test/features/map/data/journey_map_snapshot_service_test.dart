/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 29 August 2026
 * Description:
 *   Tests static Journey map fog for completion and feed previews. The fog is
 *   the cloud field drawn over the whole frame, so all this has to supply is
 *   the explored ground cleared out of it — never the unexplored ground, which
 *   is what made a long journey cost more to draw than a short one.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/activity_feed/domain/activity_route.dart';
import 'package:roam_io/features/map/data/journey_map_snapshot_service.dart';
import 'package:roam_io/features/map/data/region_polygon.dart';
import 'package:roam_io/features/map/data/region_service.dart';

void main() {
  final route = ActivityRoute.fromPoints(const [
    LatLng(-37.8136, 144.9631),
    LatLng(-37.8118, 144.9690),
  ])!;

  test('asks only for the regions the traveller had explored', () async {
    final regionService = _FakeRegionService([_region(id: 'visited-tile')]);

    await _service(regionService).loadRouteSnapshotOverlay(
      route: route,
      visitedRegionIds: const {'visited-tile'},
      currentRegionId: 'current-tile',
    );

    // Unexplored ground is covered by the sheet, never fetched: a long journey
    // crosses hundreds of tiles, and asking for all of them is what left big
    // journeys with no fog at all.
    expect(regionService.requestedIds, {'visited-tile', 'current-tile'});
    expect(
      regionService.requestedSouth,
      lessThan(route.bounds.southwest.latitude),
    );
    expect(
      regionService.requestedNorth,
      greaterThan(route.bounds.northeast.latitude),
    );
  });

  test('fogs everything without a request when nothing was explored', () async {
    final regionService = _FakeRegionService([_region(id: 'fog-tile')]);

    final overlay = await _service(regionService).loadRouteSnapshotOverlay(
      route: route,
      visitedRegionIds: const <String>{},
      currentRegionId: null,
    );

    expect(regionService.wasRequested, isFalse);
    // Nothing cleared, but a frame that loaded: the whole route is clouded over
    // rather than left as bare basemap.
    expect(overlay.clearedRegions, isEmpty);
    expect(overlay.loadedBounds, isNotNull);
    expect(overlay.covers(route.bounds), isTrue);
  });

  test('clears one region per explored tile', () async {
    final overlay =
        await _service(
          _FakeRegionService([
            _region(id: 'visited-tile'),
            _region(id: 'current-tile', west: 144.9700, east: 144.9760),
          ]),
        ).loadRouteSnapshotOverlay(
          route: route,
          visitedRegionIds: const {'visited-tile'},
          currentRegionId: 'current-tile',
        );

    expect(overlay.clearedRegions.map((region) => region.id), [
      'visited-tile',
      'current-tile',
    ]);
    expect(overlay.loadedBounds, isNotNull);
  });

  test('ignores regions returned by a backend without the id filter', () async {
    final overlay =
        await _service(
          _FakeRegionService([
            _region(id: 'visited-tile'),
            _region(id: 'someone-elses-fog-tile'),
          ]),
        ).loadRouteSnapshotOverlay(
          route: route,
          visitedRegionIds: const {'visited-tile'},
          currentRegionId: null,
        );

    expect(overlay.clearedRegions.map((region) => region.id), [
      'visited-tile',
    ]);
  });

  test('uses fitted viewport bounds when provided', () async {
    final regionService = _FakeRegionService([_region(id: 'visited-tile')]);
    final viewportBounds = LatLngBounds(
      southwest: const LatLng(-37.82, 144.95),
      northeast: const LatLng(-37.80, 144.98),
    );

    final overlay = await _service(regionService).loadRouteSnapshotOverlay(
      route: route,
      visitedRegionIds: const {'visited-tile'},
      currentRegionId: null,
      viewportBounds: viewportBounds,
    );

    expect(
      regionService.requestedSouth,
      lessThan(viewportBounds.southwest.latitude),
    );
    expect(
      regionService.requestedEast,
      greaterThan(viewportBounds.northeast.longitude),
    );
    expect(overlay.covers(viewportBounds), isTrue);
  });
}

JourneyMapSnapshotService _service(RegionService regionService) {
  return JourneyMapSnapshotService(regionService: regionService);
}

class _FakeRegionService extends RegionService {
  _FakeRegionService(this.regions);

  final List<RegionPolygon> regions;
  bool wasRequested = false;
  Set<String>? requestedIds;
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
    Set<String>? regionIds,
  }) async {
    wasRequested = true;
    requestedIds = regionIds;
    requestedSouth = south;
    requestedWest = west;
    requestedNorth = north;
    requestedEast = east;
    return regions;
  }
}

RegionPolygon _region({
  required String id,
  double west = 144.9630,
  double east = 144.9700,
}) {
  return RegionPolygon(
    id: id,
    name: id,
    areaSquareMetres: 1000,
    geometry: <String, dynamic>{
      'type': 'Polygon',
      'coordinates': <dynamic>[
        <dynamic>[
          <double>[west, -37.8140],
          <double>[east, -37.8140],
          <double>[east, -37.8110],
          <double>[west, -37.8110],
          <double>[west, -37.8140],
        ],
      ],
    },
  );
}
