import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:roam_io/features/map/data/geolocator_service.dart';
import 'package:roam_io/features/map/data/map_controller.dart';
import 'package:roam_io/features/map/data/place_of_interest.dart';
import 'package:roam_io/features/map/data/places_service.dart';
import 'package:roam_io/features/map/data/region_polygon.dart';
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
      final controller = _buildController(
        region: _region(areaSquareMetres: 4000000),
        awardedXp: awardedXp,
      );

      await controller.initialise(userId: 'user-1');

      expect(awardedXp, <int>[100]);
      expect(awardedXp.single, isNot(XpRewardConfig.baseTileUnlockXp));

      controller.disposeController();
    });

    test('already visited region does not award unlock XP', () async {
      final awardedXp = <int>[];
      final region = _region(areaSquareMetres: 4000000);
      final controller = _buildController(
        region: region,
        awardedXp: awardedXp,
        visitedRegionIds: <String>{region.id},
      );

      await controller.initialise(userId: 'user-1');

      expect(awardedXp, isEmpty);

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
  Set<String> visitedRegionIds = const <String>{},
}) {
  return MapController(
    geoLocatorService: _FakeGeoLocatorService(),
    regionService: _FakeRegionService(region),
    placesService: _FakePlacesService(),
    visitService: _FakeVisitService(),
    visitedRegionService: _FakeVisitedRegionService(
      Set<String>.from(visitedRegionIds),
    ),
    tileUnlockXpService: TileUnlockXpService(
      addXp: (xpToAdd) async => awardedXp.add(xpToAdd),
    ),
  );
}

RegionPolygon _region({required double? areaSquareMetres}) {
  return RegionPolygon(
    id: 'region-1',
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
  _FakeVisitedRegionService(this._visitedRegionIds);

  final Set<String> _visitedRegionIds;

  @override
  Future<Set<String>> loadVisitedRegionIds() async {
    return _visitedRegionIds;
  }

  @override
  Future<bool> markVisited(String regionId, {DateTime? visitedAt}) async {
    _visitedRegionIds.add(regionId);
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
