/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Tests idempotent region unlock XP awards and feedback events from the map
 *   controller.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:roam_io/features/map/data/geolocator_service.dart';
import 'package:roam_io/features/map/data/map_controller.dart';
import 'package:roam_io/features/map/data/place_of_interest.dart';
import 'package:roam_io/features/map/data/places_service.dart';
import 'package:roam_io/features/map/data/region_polygon.dart';
import 'package:roam_io/features/map/data/region_polygon_cache.dart';
import 'package:roam_io/features/map/data/region_service.dart';
import 'package:roam_io/features/map/data/tile_unlock_xp_service.dart';
import 'package:roam_io/features/map/data/visit_service.dart';
import 'package:roam_io/features/map/data/visited_region_service.dart';
import 'package:roam_io/features/profile/domain/xp_reward_config.dart';

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

      expect(awardedXp, <int>[75]);
      expect(awardedXp.single, isNot(XpRewardConfig.baseTileUnlockXp));
      expect(feedbackEvents, <String>['Region One:75']);

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

      expect(awardedXp, <int>[75]);
      expect(feedbackEvents, <String>['Region One:75']);

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

      expect(awardedXp, <int>[50, 75]);
      expect(awardedXp.last, greaterThan(awardedXp.first));
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

        expect(awardedXp, <int>[75]);
        expect(awardedXp.single, isNot(XpRewardConfig.minTileUnlockXp));
        expect(feedbackEvents, <String>['Region One:75']);

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
        visitedRegionService: _FakeVisitedRegionService(
          <String>{},
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
        visitedRegionService: _FakeVisitedRegionService(
          <String>{},
          throwOnMarkVisited: true,
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
      );

      await controller.initialise(userId: 'user-1');

      expect(events, <String>['persisted', 'xp']);
      expect(awardedXp, <int>[75]);

      controller.disposeController();
    });

    test('level-up suppresses normal unlock feedback', () async {
      final awardedXp = <int>[];
      final feedbackEvents = <String>[];
      final controller = _buildController(
        region: _region(areaSquareMetres: 4000000),
        awardedXp: awardedXp,
        feedbackEvents: feedbackEvents,
        didLevelUpOnAddXp: true,
      );

      await controller.initialise(userId: 'user-1');

      expect(awardedXp, <int>[75]);
      expect(feedbackEvents, isEmpty);

      controller.disposeController();
    });

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

      expect(awardedXp, <int>[XpRewardConfig.minTileUnlockXp]);

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
  RegionPolygonCache? regionPolygonCache,
  bool throwOnAddXp = false,
  bool didLevelUpOnAddXp = false,
}) {
  final controller = MapController(
    geoLocatorService: _FakeGeoLocatorService(),
    regionService: _FakeRegionService(region),
    placesService: _FakePlacesService(),
    visitService: _FakeVisitService(),
    regionPolygonCache: regionPolygonCache,
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
        return didLevelUpOnAddXp;
      },
    ),
  );

  controller.onRegionUnlockRewarded = (region, xpAwarded) {
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVisitService implements VisitService {
  @override
  Future<Set<int>> getVisitedPlaceIds(String userId) async => <int>{};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVisitedRegionService implements VisitedRegionService {
  _FakeVisitedRegionService(
    this._visitedRegionIds, {
    this.persistNewUnlocks = true,
    this.throwOnMarkVisited = false,
    this.events,
  });

  final Set<String> _visitedRegionIds;
  final bool persistNewUnlocks;
  final bool throwOnMarkVisited;
  final List<String>? events;

  @override
  Future<Set<String>> loadVisitedRegionIds() async {
    return _visitedRegionIds;
  }

  @override
  Future<bool> markVisited(String regionId, {DateTime? visitedAt}) async {
    if (throwOnMarkVisited) {
      throw Exception('Could not persist region visit');
    }

    if (!persistNewUnlocks || _visitedRegionIds.contains(regionId)) {
      return false;
    }

    _visitedRegionIds.add(regionId);
    events?.add('persisted');
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
