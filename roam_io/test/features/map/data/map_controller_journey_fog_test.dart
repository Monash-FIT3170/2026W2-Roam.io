/*
 * Description:
 *   Tests that journey tracking keeps clearing fog. The map's own location
 *   stream is silent in every test here, which is what the app looks like once
 *   it is backgrounded: only the journey's background-capable stream survives,
 *   and its route points have to keep unlocking tiles on their own.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/map/data/geolocator_service.dart';
import 'package:roam_io/features/map/data/map_controller.dart';
import 'package:roam_io/features/map/data/place_marker_manager.dart';
import 'package:roam_io/features/map/data/place_of_interest.dart';
import 'package:roam_io/features/map/data/places_service.dart';
import 'package:roam_io/features/map/data/region_polygon.dart';
import 'package:roam_io/features/map/data/region_service.dart';
import 'package:roam_io/features/map/data/tile_unlock_xp_service.dart';
import 'package:roam_io/features/map/data/visit_service.dart';
import 'package:roam_io/features/map/data/visited_region_service.dart';
import 'package:roam_io/features/map/fog/fog_decay_difficulty.dart';
import 'package:roam_io/features/profile/domain/xp_award_result.dart';
import 'package:roam_io/features/you/services/exploration_stats_service.dart';
import 'package:roam_io/services/polygon_service.dart';

/// Start position, inside [_startRegion].
const _startLocation = LatLng(-37.0, 144.0);

/// A tile away from the start, inside [_nextRegion].
const _nextLocation = LatLng(-38.5, 144.0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapController journey-driven fog clearing', () {
    test(
      'a tracked location unlocks and clears the tile it falls in',
      () async {
        final regionService = _FakeRegionService();
        final controller = _buildController(regionService: regionService);

        await controller.initialise(userId: 'user-1');
        expect(controller.currentRegion?.id, 'region-start');

        controller.followTrackedLocation(_nextLocation);
        await pumpEventQueue();

        expect(controller.currentRegion?.id, 'region-next');
        expect(controller.visitedRegionIds, contains('region-next'));
        expect(controller.fogClearedRegionIds, contains('region-next'));
        expect(
          controller.fogController.geometry?.contains('region-next'),
          isTrue,
        );

        controller.disposeController();
      },
    );

    test('the cleared tile dissolves from the tracked location', () async {
      final controller = _buildController(regionService: _FakeRegionService());

      await controller.initialise(userId: 'user-1');

      controller.followTrackedLocation(_nextLocation);
      await pumpEventQueue();

      expect(
        controller.fogController.dissolveSet.contains('region-next'),
        isTrue,
      );

      controller.disposeController();
    });

    test(
      'republishing the same route point does not re-resolve the region',
      () async {
        final regionService = _FakeRegionService();
        final controller = _buildController(regionService: regionService);

        await controller.initialise(userId: 'user-1');
        final lookupsAfterStartup = regionService.calls;

        // Journey tracking notifies once a second while its elapsed timer runs,
        // republishing the same latest route point every time.
        controller.followTrackedLocation(_nextLocation);
        await pumpEventQueue();
        controller.followTrackedLocation(_nextLocation);
        controller.followTrackedLocation(_nextLocation);
        await pumpEventQueue();

        expect(regionService.calls, lookupsAfterStartup + 1);

        controller.disposeController();
      },
    );

    test(
      'a tracked location past the movement threshold resolves again',
      () async {
        final regionService = _FakeRegionService();
        final controller = _buildController(regionService: regionService);

        await controller.initialise(userId: 'user-1');
        final lookupsAfterStartup = regionService.calls;

        controller.followTrackedLocation(_nextLocation);
        await pumpEventQueue();
        controller.followTrackedLocation(_metresNorthOf(_nextLocation, 20));
        await pumpEventQueue();

        expect(regionService.calls, lookupsAfterStartup + 2);

        controller.disposeController();
      },
    );
  });
}

/// Offsets [origin] by [metres] of latitude, far enough to clear the region
/// check's movement threshold without leaving the tile.
LatLng _metresNorthOf(LatLng origin, double metres) {
  const metresPerDegreeLatitude = 111320.0;
  return LatLng(
    origin.latitude + metres / metresPerDegreeLatitude,
    origin.longitude,
  );
}

MapController _buildController({required _FakeRegionService regionService}) {
  return MapController(
    geoLocatorService: _SilentGeoLocatorService(),
    regionService: regionService,
    placeMarkerManager: PlaceMarkerManager(placesService: _FakePlacesService()),
    visitService: _FakeVisitService(),
    polygonService: PolygonService(firestore: FakeFirebaseFirestore()),
    explorationStatsService: _FakeExplorationStatsService(),
    visitedRegionService: _FakeVisitedRegionService(),
    tileUnlockXpService: TileUnlockXpService(
      addXp: (xpToAdd) async => XpAwardResult.success(
        amount: xpToAdd,
        previousXp: 0,
        newXp: xpToAdd,
        previousLevel: 1,
        newLevel: 1,
        historyRecorded: true,
      ),
    ),
  );
}

RegionPolygon _region({
  required String id,
  required Map<String, dynamic> geometry,
}) {
  return RegionPolygon(
    id: id,
    name: id,
    areaSquareMetres: 1000000,
    geometry: geometry,
  );
}

final _startRegion = _region(id: 'region-start', geometry: _startGeometry);
final _nextRegion = _region(id: 'region-next', geometry: _nextGeometry);

/// Location source that resolves one fix and then goes quiet, standing in for a
/// backgrounded app whose foreground stream has stopped delivering.
class _SilentGeoLocatorService implements GeoLocatorService {
  @override
  Future<Position> getCurrentLocation() async {
    return Position(
      longitude: _startLocation.longitude,
      latitude: _startLocation.latitude,
      timestamp: DateTime(2026, 5, 12),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
    );
  }

  @override
  Future<Stream<Position>> getLocationUpdates({
    bool allowBackgroundUpdates = false,
  }) async {
    return const Stream<Position>.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Splits the world at latitude -37.5 so a tracked point can move between two
/// known tiles, and counts lookups so redundant ones are visible.
class _FakeRegionService implements RegionService {
  int calls = 0;

  @override
  Future<RegionPolygon?> getContainingRegion({
    required double lat,
    required double lng,
  }) async {
    calls++;
    return lat > -37.5 ? _startRegion : _nextRegion;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePlacesService implements PlacesService {
  @override
  Future<List<PlaceOfInterest>> getPlacesForRegion({
    required String regionId,
  }) async {
    return const <PlaceOfInterest>[];
  }

  @override
  Future<Map<String, List<PlaceOfInterest>>> getPlacesForRegions({
    required List<String> regionIds,
  }) async {
    return {
      for (final regionId in regionIds) regionId: const <PlaceOfInterest>[],
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVisitService implements VisitService {
  @override
  Future<Set<int>> getVisitedPlaceIds(String userId) async => <int>{};

  @override
  Future<Map<String, int>> getVisitCountsByRegion(
    String userId, {
    Set<String>? validRegionIds,
  }) async {
    return const <String, int>{};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVisitedRegionService implements VisitedRegionService {
  final Set<String> _visitedRegionIds = <String>{};

  @override
  Future<Set<String>> loadVisitedRegionIds() async => _visitedRegionIds;

  @override
  Future<Set<String>> loadFogClearedRegionIds({
    required FogDecayDifficulty difficulty,
    DateTime? now,
  }) async => _visitedRegionIds;

  @override
  Future<void> refreshFogDecayWarnings({
    required FogDecayDifficulty difficulty,
    DateTime? now,
  }) async {}

  @override
  Future<Map<String, DateTime>> loadUnpresentedFogDecayEvents({
    required FogDecayDifficulty difficulty,
    DateTime? now,
  }) async => <String, DateTime>{};

  @override
  Future<void> markFogDecayEventsPresented(
    Map<String, DateTime> decayAtByRegionId,
  ) async {}

  @override
  Future<bool> markVisited(
    String regionId, {
    DateTime? visitedAt,
    double? areaSquareMetres,
    String? name,
  }) async {
    return _visitedRegionIds.add(regionId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeExplorationStatsService extends ExplorationStatsService {
  _FakeExplorationStatsService()
    : super(polygonService: PolygonService(firestore: FakeFirebaseFirestore()));

  final Set<String> _unlockedRegionIds = <String>{};

  @override
  Future<bool> recordUnlock({
    required String profileId,
    required RegionPolygon region,
    DateTime? visitedAt,
  }) async {
    return _unlockedRegionIds.add(region.id);
  }

  @override
  Future<void> recordReentry({
    required String profileId,
    required String polygonId,
    DateTime? enteredAt,
  }) async {}
}

const Map<String, dynamic> _startGeometry = <String, dynamic>{
  'type': 'Polygon',
  'coordinates': <dynamic>[
    <dynamic>[
      <double>[144.0, -37.0],
      <double>[145.0, -37.0],
      <double>[145.0, -37.5],
      <double>[144.0, -37.5],
      <double>[144.0, -37.0],
    ],
  ],
};

const Map<String, dynamic> _nextGeometry = <String, dynamic>{
  'type': 'Polygon',
  'coordinates': <dynamic>[
    <dynamic>[
      <double>[144.0, -37.5],
      <double>[145.0, -37.5],
      <double>[145.0, -39.0],
      <double>[144.0, -39.0],
      <double>[144.0, -37.5],
    ],
  ],
};
