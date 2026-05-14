import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:roam_io/features/map/data/geolocator_service.dart';
import 'package:roam_io/features/map/data/place_of_interest.dart';
import 'package:roam_io/features/map/data/visit_service.dart';
import 'package:roam_io/features/map/data/visited_region_service.dart';
import 'package:roam_io/services/polygon_service.dart';

/// Test [Position] near Melbourne CBD.
Position testPosition(double lat, double lng) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime(2026, 1, 1),
  accuracy: 1,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

/// Overrides [GeoLocatorService.getCurrentLocation] for deterministic tests.
class FakeGeoLocatorService extends GeoLocatorService {
  FakeGeoLocatorService(this._position, {this.throwOnGet = false});

  final Position? _position;
  final bool throwOnGet;

  @override
  Future<Position> getCurrentLocation() async {
    if (throwOnGet || _position == null) {
      throw Exception('location unavailable');
    }
    return _position;
  }
}

/// [VisitService] backed by fake Firestore with overridable visit ID loading.
class RecordingVisitService extends VisitService {
  RecordingVisitService({Set<int>? initialIds})
    : _ids = {...?initialIds},
      super(firestore: FakeFirebaseFirestore());

  final Set<int> _ids;
  Object? markVisitedError;
  int markVisitedCallCount = 0;

  @override
  Future<Set<int>> getVisitedPlaceIds(String userId) async =>
      Set<int>.from(_ids);

  @override
  Future<void> markVisited({
    required String userId,
    required PlaceOfInterest place,
    String? customName,
    String? description,
    List<String>? mediaUrls,
  }) async {
    markVisitedCallCount++;
    final err = markVisitedError;
    if (err != null) {
      throw err;
    }
    _ids.add(place.id);
    await super.markVisited(
      userId: userId,
      place: place,
      customName: customName,
      description: description,
      mediaUrls: mediaUrls,
    );
  }
}

/// Test double for [VisitedRegionService] without touching [FirebaseAuth.instance].
class FakeVisitedRegionService extends VisitedRegionService {
  FakeVisitedRegionService({this.markVisitedResult = true})
    : super(
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'test-user', email: 'test@test.com'),
        ),
        polygonService: PolygonService(firestore: FakeFirebaseFirestore()),
      );

  final bool markVisitedResult;
  int markVisitedCalls = 0;

  @override
  Future<Set<String>> loadVisitedRegionIds() async => <String>{};

  @override
  Future<bool> markVisited(String regionId, {DateTime? visitedAt}) async {
    markVisitedCalls++;
    return markVisitedResult;
  }
}

/// Shared test place near Melbourne.
PlaceOfInterest testPlace({
  int id = 1,
  String? name,
  LatLng location = const LatLng(-37.8136, 144.9631),
  String regionId = 'region-1',
}) {
  return PlaceOfInterest(
    id: id,
    googlePlaceId: 'gp-$id',
    name: name ?? 'Test Place $id',
    category: PlaceCategory.other,
    types: const <String>[],
    location: location,
    regionId: regionId,
  );
}
