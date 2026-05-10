import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/mapfeature/Place_of_interest.dart';
import 'package:roam_io/features/mapfeature/geolocator_service.dart';
import 'package:roam_io/features/mapfeature/map_controller.dart';
import 'package:roam_io/features/mapfeature/places_service.dart';
import 'package:roam_io/features/mapfeature/region_polygon.dart';
import 'package:roam_io/features/mapfeature/region_polygon_cache.dart';
import 'package:roam_io/features/mapfeature/region_service.dart';
import 'package:roam_io/features/mapfeature/visit_service.dart';
import 'package:roam_io/features/mapfeature/visited_region_service.dart';
import 'package:roam_io/services/polygon_service.dart';

const fakeUserID = 'user-1';

// The latitude boundary that separates Region A (south) from Region B (north).
// The FakeRegionService uses this to decide which region a position falls in.
const fakeRegionBoundaryLat = -37.75;

// Two geographically distinct regions used across all tests.
final _regionA = _makeRegion(
  id: 'region-a',
  name: 'Region A',
  lat: -37.8136, // south of boundary - always resolves to Region A
  lng: 144.9631,
);

final _regionB = _makeRegion(
  id: 'region-b',
  name: 'Region B',
  lat: -37.7036, // north of boundary - always resolves to Region B
  lng: 144.9631,
);

// GPS positions that place the user firmly inside each region.
final _positionInRegionA = _makePosition(lat: -37.8136, lng: 144.9631);
final _positionInRegionB = _makePosition(lat: -37.7036, lng: 144.9631);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapController — region visit tracking', () {
    late StreamController<Position> locationStream;
    late RecordingVisitedRegionService visitedRegionService;
    late MapController controller;

    setUp(() {
      locationStream = StreamController<Position>();
      visitedRegionService = RecordingVisitedRegionService();

      controller = MapController(
        geoLocatorService: FakeGeoLocatorService(
          initialPosition: _positionInRegionA,
          updates: locationStream.stream,
        ),
        regionService: FakeRegionService(
          regionForPosition: ({required double lat, required double lng}) {
            return lat < fakeRegionBoundaryLat ? _regionA : _regionB;
          },
        ),
        visitedRegionService: visitedRegionService,
        polygonCacheManager: RegionPolygonCache(),
        // Not under test — required by MapController constructor.
        placesService: FakePlacesService(),
        visitService: FakeVisitService(),
      );
    });

    tearDown(() async {
      await controller.disposeController();
      await locationStream.close();
    });

    test('marks the starting region as visited on initialisation', () async {
      await controller.initialise(userId: fakeUserID);

      // The user started in Region A, so it should be visited immediately.
      expect(visitedRegionService.markedRegionIds, ['region-a']);
      expect(controller.visitedPolygonIds, contains('region-a'));
    });

    test(
      'marks a new region as visited after the user moves into it',
      () async {
        await controller.initialise(userId: fakeUserID);

        await _moveUserTo(
          _positionInRegionB,
          via: locationStream,
          until: () =>
              visitedRegionService.markedRegionIds.contains('region-b'),
        );

        expect(visitedRegionService.markedRegionIds, ['region-a', 'region-b']);
        expect(
          controller.visitedPolygonIds,
          containsAll(['region-a', 'region-b']),
        );
      },
    );

    test(
      'does not mark a region as visited again when the user re-enters it',
      () async {
        await controller.initialise(userId: fakeUserID);

        await _moveUserTo(
          _positionInRegionB,
          via: locationStream,
          until: () =>
              visitedRegionService.markedRegionIds.contains('region-b'),
        );

        await _moveUserTo(
          _positionInRegionA,
          via: locationStream,
          until: () => true,
        );

        // Region A was already visited — it should not appear in the list twice.
        expect(
          visitedRegionService.markedRegionIds,
          ['region-a', 'region-b'],
          reason: 'revisiting a polygon should not call markVisited again',
        );
      },
    );

    test('renders a visited polygon as transparent', () async {
      await controller.initialise(userId: fakeUserID);

      await _moveUserTo(
        _positionInRegionB,
        via: locationStream,
        until: () => visitedRegionService.markedRegionIds.contains('region-b'),
      );

      // A visited polygon should have a transparent fill so the map shows
      // through, indicating the user has explored this region.
      final polygonB = _findPolygon(controller.polygons, id: 'region-b');
      expect(polygonB.fillColor, const Color(0x00000000));
    });

    test('renders an unvisited polygon as dark', () async {
      await controller.initialise(userId: fakeUserID);

      // The user starts in Region A. Region B has not been visited yet.
      final polygonB = _findPolygon(controller.polygons, id: 'region-b');
      expect(polygonB.fillColor, const Color(0xCC080808));
    });
  });
}

// Simulates device location. Starts at a fixed position and accepts injected
// updates via a stream so tests can move the user around.
class FakeGeoLocatorService extends GeoLocatorService {
  FakeGeoLocatorService({required this.initialPosition, required this.updates});

  final Position initialPosition;
  final Stream<Position> updates;

  @override
  Future<Position> getCurrentLocation() async => initialPosition;

  @override
  Future<Stream<Position>> getLocationUpdates() async => updates;
}

// Returns a region based on regionForPosition logic.
class FakeRegionService extends RegionService {
  FakeRegionService({required this.regionForPosition});

  final RegionPolygon? Function({required double lat, required double lng})
  regionForPosition;

  @override
  Future<RegionPolygon?> getContainingRegion({
    required double lat,
    required double lng,
  }) async => regionForPosition(lat: lat, lng: lng);

  @override
  Future<List<RegionPolygon>> getRegionsForViewport({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async => <RegionPolygon>[];
}

// Records every region that gets marked as visited so tests can assert on it.
class RecordingVisitedRegionService extends VisitedRegionService {
  RecordingVisitedRegionService()
    : super(
        auth: MockFirebaseAuth(),
        polygonService: PolygonService(firestore: FakeFirebaseFirestore()),
      );

  final List<String> markedRegionIds = <String>[];

  @override
  Future<Set<String>> loadVisitedRegionIds() async => <String>{};

  @override
  Future<bool> markVisited(String regionId, {DateTime? visitedAt}) async {
    markedRegionIds.add(regionId);
    return true;
  }
}

class FakePlacesService extends PlacesService {
  @override
  Future<List<PlaceOfInterest>> getPlacesForRegion({
    required String regionId,
  }) async => <PlaceOfInterest>[];
}

class FakeVisitService extends VisitService {
  FakeVisitService() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<Set<int>> getVisitedPlaceIds(String userId) async => <int>{};
}

RegionPolygon _makeRegion({
  required String id,
  required String name,
  required double lat,
  required double lng,
}) {
  return RegionPolygon(
    id: id,
    name: name,
    geometry: <String, dynamic>{
      'type': 'Polygon',
      'coordinates': <dynamic>[
        <dynamic>[
          <dynamic>[lng, lat],
          <dynamic>[lng + 0.01, lat],
          <dynamic>[lng + 0.01, lat + 0.01],
          <dynamic>[lng, lat + 0.01],
          <dynamic>[lng, lat],
        ],
      ],
    },
  );
}

Position _makePosition({required double lat, required double lng}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime(2026, 5, 10),
    accuracy: 1,
    altitude: 0,
    altitudeAccuracy: 1,
    heading: 0,
    headingAccuracy: 1,
    speed: 0,
    speedAccuracy: 1,
  );
}

Polygon _findPolygon(Set<Polygon> polygons, {required String id}) {
  return polygons.singleWhere(
    (p) => p.polygonId.value == id,
    orElse: () => throw StateError('No polygon found with id "$id"'),
  );
}

// Pushes a new position into the location stream and waits until [until]
// returns true, meaning the controller has finished processing the move.
// This exists because MapController processes location updates asynchronously —
// we can't simply await a future after emitting a position.
Future<void> _moveUserTo(
  Position position, {
  required StreamController<Position> via,
  required bool Function() until,
  Duration timeout = const Duration(seconds: 2),
}) async {
  via.add(position);

  final stopwatch = Stopwatch()..start();
  while (!until()) {
    if (stopwatch.elapsed > timeout) {
      fail(
        'Timed out after ${timeout.inSeconds}s waiting for the controller to process the location update',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
