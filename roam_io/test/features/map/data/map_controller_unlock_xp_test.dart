/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 17/05/2026
 * Description:
 *   Tests idempotent region unlock XP awards and feedback events from the map
 *   controller.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:roam_io/features/map/data/geolocator_service.dart';
import 'package:roam_io/features/map/data/map_controller.dart';
import 'package:roam_io/features/map/data/place_marker_manager.dart';
import 'package:roam_io/features/map/data/place_of_interest.dart';
import 'package:roam_io/features/map/data/places_service.dart';
import 'package:roam_io/features/map/data/region_polygon.dart';
import 'package:roam_io/features/map/data/region_polygon_cache.dart';
import 'package:roam_io/features/map/data/region_service.dart';
import 'package:roam_io/features/map/data/tile_unlock_xp_service.dart';
import 'package:roam_io/features/map/data/visit_service.dart';
import 'package:roam_io/features/map/data/visited_region_service.dart';
import 'package:roam_io/features/profile/domain/xp_award_result.dart';
import 'package:roam_io/features/you/services/exploration_stats_service.dart';
import 'package:roam_io/services/polygon_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapController region unlock XP', () {
    test('first-time region unlock awards XP from areaSquareMetres', () async {
      final awardedXp = <int>[];
      final feedbackEvents = <String>[];
      final controller = _buildController(
        region: _region(areaSquareMetres: 4000000),
        awardedXp: awardedXp,
        feedbackEvents: feedbackEvents,
      );

      await controller.initialise(userId: 'user-1');

      expect(awardedXp, <int>[50]);
      expect(feedbackEvents, <String>['Region One:50']);

      controller.disposeController();
    });

    test('first-time reference-area region unlock awards 50 XP', () async {
      final awardedXp = <int>[];
      final feedbackEvents = <String>[];
      final controller = _buildController(
        region: _region(areaSquareMetres: 1000000),
        awardedXp: awardedXp,
        feedbackEvents: feedbackEvents,
      );

      await controller.initialise(userId: 'user-1');

      expect(awardedXp, <int>[50]);
      expect(feedbackEvents, <String>['Region One:50']);

      controller.disposeController();
    });

    test('rechecking the same polygon does not award XP twice', () async {
      final awardedXp = <int>[];
      final feedbackEvents = <String>[];
      final region = _region(areaSquareMetres: 4000000);
      final visitedRegionService = _FakeVisitedRegionService(<String>{});
      final controller = _buildController(
        region: region,
        awardedXp: awardedXp,
        feedbackEvents: feedbackEvents,
        visitedRegionService: visitedRegionService,
      );

      await controller.initialise(userId: 'user-1');
      await controller.initialise(userId: 'user-1');

      expect(awardedXp, <int>[50]);
      expect(feedbackEvents, <String>['Region One:50']);

      controller.disposeController();
    });

    test('multiple different polygons can each award XP once', () async {
      final awardedXp = <int>[];
      final visitedRegionService = _FakeVisitedRegionService(<String>{});

      final smallController = _buildController(
        region: _region(id: 'region-small', areaSquareMetres: 1000000),
        awardedXp: awardedXp,
        visitedRegionService: visitedRegionService,
      );
      await smallController.initialise(userId: 'user-1');
      smallController.disposeController();

      final largeController = _buildController(
        region: _region(id: 'region-large', areaSquareMetres: 4000000),
        awardedXp: awardedXp,
        visitedRegionService: visitedRegionService,
      );
      await largeController.initialise(userId: 'user-1');
      largeController.disposeController();

      expect(awardedXp, <int>[50, 50]);
    });

    test(
      'cached polygon area is used when containing region omits area',
      () async {
        final awardedXp = <int>[];
        final feedbackEvents = <String>[];

        final cache = RegionPolygonCache();

        final cachedRegion = _region(areaSquareMetres: 4000000);

        cache.cacheRegion(
          region: cachedRegion,
          isVisited: false,
          isCurrentRegion: false,
          onRegionTapped: (_, _) {},
        );

        final controller = _buildController(
          region: _region(areaSquareMetres: null),
          awardedXp: awardedXp,
          feedbackEvents: feedbackEvents,
          regionPolygonCache: cache,
        );

        await controller.initialise(userId: 'user-1');

        expect(awardedXp, <int>[50]);

        expect(feedbackEvents, <String>['Region One:50']);

        controller.disposeController();
      },
    );
    test('persistence returning false prevents XP', () async {
      final awardedXp = <int>[];
      final feedbackEvents = <String>[];
      final controller = _buildController(
        region: _region(areaSquareMetres: 4000000),
        awardedXp: awardedXp,
        feedbackEvents: feedbackEvents,
        explorationStatsService: _FakeExplorationStatsService(
          persistNewUnlocks: false,
        ),
      );

      await controller.initialise(userId: 'user-1');

      expect(awardedXp, isEmpty);
      expect(feedbackEvents, isEmpty);

      controller.disposeController();
    });

    test('persistence failure prevents XP', () async {
      final awardedXp = <int>[];
      final feedbackEvents = <String>[];
      final controller = _buildController(
        region: _region(areaSquareMetres: 4000000),
        awardedXp: awardedXp,
        feedbackEvents: feedbackEvents,
        explorationStatsService: _FakeExplorationStatsService(
          throwOnRecordUnlock: true,
        ),
      );

      await controller.initialise(userId: 'user-1');

      expect(awardedXp, isEmpty);
      expect(feedbackEvents, isEmpty);

      controller.disposeController();
    });

    test('XP write failure prevents feedback', () async {
      final awardedXp = <int>[];
      final feedbackEvents = <String>[];
      final controller = _buildController(
        region: _region(areaSquareMetres: 4000000),
        awardedXp: awardedXp,
        feedbackEvents: feedbackEvents,
        throwOnAddXp: true,
      );

      await controller.initialise(userId: 'user-1');

      expect(awardedXp, isEmpty);
      expect(feedbackEvents, isEmpty);

      controller.disposeController();
    });

    test('XP is awarded only after persistence succeeds', () async {
      final awardedXp = <int>[];
      final events = <String>[];
      final controller = _buildController(
        region: _region(areaSquareMetres: 4000000),
        awardedXp: awardedXp,
        events: events,
        explorationStatsService: _FakeExplorationStatsService(events: events),
      );

      await controller.initialise(userId: 'user-1');

      expect(events, <String>['persisted', 'xp']);
      expect(awardedXp, <int>[50]);

      controller.disposeController();
    });

    test(
      'level-up still emits unlock feedback for celebration toast',
      () async {
        final awardedXp = <int>[];
        final feedbackEvents = <String>[];
        final controller = _buildController(
          region: _region(areaSquareMetres: 4000000),
          awardedXp: awardedXp,
          feedbackEvents: feedbackEvents,
          didLevelUpOnAddXp: true,
        );

        await controller.initialise(userId: 'user-1');

        expect(awardedXp, <int>[50]);
        expect(feedbackEvents, <String>['Region One:50']);

        controller.disposeController();
      },
    );

    test('already visited region does not award unlock XP', () async {
      final awardedXp = <int>[];
      final feedbackEvents = <String>[];
      final region = _region(areaSquareMetres: 4000000);
      final controller = _buildController(
        region: region,
        awardedXp: awardedXp,
        feedbackEvents: feedbackEvents,
        visitedRegionIds: <String>{region.id},
      );

      await controller.initialise(userId: 'user-1');

      expect(awardedXp, isEmpty);
      expect(feedbackEvents, isEmpty);

      controller.disposeController();
    });

    test('missing area awards minimum fallback XP', () async {
      final awardedXp = <int>[];
      final controller = _buildController(
        region: _region(areaSquareMetres: null),
        awardedXp: awardedXp,
      );

      await controller.initialise(userId: 'user-1');

      expect(awardedXp, <int>[50]);
      controller.disposeController();
    });
  });
}

MapController _buildController({
  required RegionPolygon region,
  required List<int> awardedXp,
  List<String>? events,
  List<String>? feedbackEvents,
  Set<String> visitedRegionIds = const <String>{},
  _FakeVisitedRegionService? visitedRegionService,
  ExplorationStatsService? explorationStatsService,
  RegionPolygonCache? regionPolygonCache,
  bool throwOnAddXp = false,
  bool didLevelUpOnAddXp = false,
}) {
  final controller = MapController(
    geoLocatorService: _FakeGeoLocatorService(),
    regionService: _FakeRegionService(region),
    placeMarkerManager: PlaceMarkerManager(placesService: _FakePlacesService()),
    visitService: _FakeVisitService(),
    regionPolygonCache: regionPolygonCache,
    polygonService: PolygonService(firestore: FakeFirebaseFirestore()),
    explorationStatsService:
        explorationStatsService ??
        ExplorationStatsService(
          polygonService: PolygonService(firestore: FakeFirebaseFirestore()),
        ),
    visitedRegionService:
        visitedRegionService ??
        _FakeVisitedRegionService(
          Set<String>.from(visitedRegionIds),
          events: events,
        ),
    tileUnlockXpService: TileUnlockXpService(
      addXp: (xpToAdd) async {
        if (throwOnAddXp) {
          throw Exception('Could not add XP');
        }
        events?.add('xp');
        awardedXp.add(xpToAdd);
        return XpAwardResult.success(
          amount: xpToAdd,
          previousXp: 0,
          newXp: xpToAdd,
          previousLevel: 1,
          newLevel: didLevelUpOnAddXp ? 2 : 1,
          historyRecorded: true,
        );
      },
    ),
  );

  controller.onRegionUnlockRewarded = (region, xpAwarded) {
    feedbackEvents?.add('${region.name}:$xpAwarded');
  };
  controller.onRegionUnlockCelebrationRewarded = (region, xpAwarded) {
    feedbackEvents?.add('${region.name}:$xpAwarded');
  };

  return controller;
}

RegionPolygon _region({
  String id = 'region-1',
  required double? areaSquareMetres,
}) {
  return RegionPolygon(
    id: id,
    name: 'Region One',
    areaSquareMetres: areaSquareMetres,
    geometry: _polygonGeometry,
  );
}

class _FakeGeoLocatorService implements GeoLocatorService {
  @override
  Future<Position> getCurrentLocation() async {
    return Position(
      longitude: 144.0,
      latitude: -37.0,
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
  Future<Stream<Position>> getLocationUpdates() async {
    return const Stream<Position>.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRegionService implements RegionService {
  const _FakeRegionService(this.region);

  final RegionPolygon region;

  @override
  Future<RegionPolygon?> getContainingRegion({
    required double lat,
    required double lng,
  }) async {
    return region;
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
  _FakeVisitedRegionService(this._visitedRegionIds, {this.events});

  final Set<String> _visitedRegionIds;
  final List<String>? events;

  @override
  Future<Set<String>> loadVisitedRegionIds() async {
    return _visitedRegionIds;
  }

  @override
  Future<bool> markVisited(
    String regionId, {
    DateTime? visitedAt,
    double? areaSquareMetres,
    String? name,
  }) async {
    if (_visitedRegionIds.contains(regionId)) {
      return false;
    }

    _visitedRegionIds.add(regionId);
    events?.add('persisted');
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeExplorationStatsService extends ExplorationStatsService {
  _FakeExplorationStatsService({
    this.persistNewUnlocks = true,
    this.throwOnRecordUnlock = false,
    this.events,
  }) : super(
         polygonService: PolygonService(firestore: FakeFirebaseFirestore()),
       );

  final bool persistNewUnlocks;
  final bool throwOnRecordUnlock;
  final List<String>? events;
  final Set<String> _unlockedRegionIds = <String>{};

  @override
  Future<bool> recordUnlock({
    required String profileId,
    required RegionPolygon region,
    DateTime? visitedAt,
  }) async {
    if (throwOnRecordUnlock) {
      throw Exception('Could not persist region visit');
    }

    if (!persistNewUnlocks || _unlockedRegionIds.contains(region.id)) {
      return false;
    }

    _unlockedRegionIds.add(region.id);
    events?.add('persisted');
    return true;
  }

  @override
  Future<void> recordReentry({
    required String profileId,
    required String polygonId,
    DateTime? enteredAt,
  }) async {}
}

const Map<String, dynamic> _polygonGeometry = <String, dynamic>{
  'type': 'Polygon',
  'coordinates': <dynamic>[
    <dynamic>[
      <double>[144.0, -37.0],
      <double>[145.0, -37.0],
      <double>[145.0, -38.0],
      <double>[144.0, -38.0],
      <double>[144.0, -37.0],
    ],
  ],
};
