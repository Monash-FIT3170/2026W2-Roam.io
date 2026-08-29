/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 28 August 2026
 * Description:
 *   Tests static Journey map fog for completion and feed previews. Fog is one
 *   sheet with a hole per explored region, so a long journey costs the same to
 *   draw as a short one instead of one polygon per census tile it crosses.
 */

import 'dart:ui';

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
    final fog = overlay.tilePolygons.single;
    expect(fog.fillColor, const Color(0xCC000000));
    expect(fog.zIndex, 5);
    expect(fog.holes, isEmpty);
    expect(_bounds(fog.points).contains(route.bounds.southwest), isTrue);
    expect(_bounds(fog.points).contains(route.bounds.northeast), isTrue);
  });

  test('cuts one hole per explored region', () async {
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

    final fog = overlay.tilePolygons.single;
    expect(fog.holes, hasLength(2));
    expect(overlay.loadedBounds, isNotNull);
    expect(overlay.polygonsForVisibleBounds(route.bounds), {fog});
  });

  test('keeps the sheet wider than every hole it carries', () async {
    // A region can run well past the framed route, and a hole crossing the
    // sheet's own edge does not render as cleared ground.
    final overlay =
        await _service(
          _FakeRegionService([
            _region(id: 'visited-tile', west: 140.0, east: 149.0),
          ]),
        ).loadRouteSnapshotOverlay(
          route: route,
          visitedRegionIds: const {'visited-tile'},
          currentRegionId: null,
        );

    final fog = overlay.tilePolygons.single;
    final sheet = _bounds(fog.points);
    for (final hole in fog.holes) {
      for (final point in hole) {
        expect(sheet.contains(point), isTrue);
      }
    }
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

    expect(overlay.tilePolygons.single.holes, hasLength(1));
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

LatLngBounds _bounds(List<LatLng> points) {
  var south = 90.0;
  var north = -90.0;
  var west = 180.0;
  var east = -180.0;
  for (final point in points) {
    south = point.latitude < south ? point.latitude : south;
    north = point.latitude > north ? point.latitude : north;
    west = point.longitude < west ? point.longitude : west;
    east = point.longitude > east ? point.longitude : east;
  }
  return LatLngBounds(
    southwest: LatLng(south, west),
    northeast: LatLng(north, east),
  );
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
