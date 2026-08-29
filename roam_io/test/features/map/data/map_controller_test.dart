/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 17/05/2026
 * Description:
 *   Unit tests for MapController proximity checks and visit marking outcomes.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/map/data/map_controller.dart';
import 'package:roam_io/features/map/fog/fog_decay_difficulty.dart';
import 'package:roam_io/services/polygon_service.dart';

import '../../../support/map_test_doubles.dart';

class _FakePolygonService extends PolygonService {
  _FakePolygonService({required this.entryCounts})
    : super(firestore: FakeFirebaseFirestore());

  final Map<String, int> entryCounts;
  int getPolygonEntryCountsCalls = 0;
  String? lastProfileId;
  Set<String>? lastValidPolygonIds;

  @override
  Future<Map<String, int>> getPolygonEntryCounts({
    required String profileId,
    Set<String>? validPolygonIds,
  }) async {
    getPolygonEntryCountsCalls++;
    lastProfileId = profileId;
    lastValidPolygonIds = validPolygonIds;
    return Map<String, int>.from(entryCounts);
  }
}

class _FakeVisitedRegionService extends FakeVisitedRegionService {
  _FakeVisitedRegionService({required Set<String> regionIds})
    : _regionIds = regionIds;

  final Set<String> _regionIds;

  @override
  Future<Set<String>> loadVisitedRegionIds() async => _regionIds;

  @override
  Future<Set<String>> loadFogClearedRegionIds({
    required FogDecayDifficulty difficulty,
    DateTime? now,
  }) async => _regionIds;

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
}

void main() {
  group('MapController location following', () {
    test(
      'user camera movement pauses following and recenter resumes it',
      () async {
        final controller = MapController(
          geoLocatorService: FakeGeoLocatorService(
            testPosition(-37.8136, 144.9631),
          ),
          visitService: RecordingVisitService(),
          visitedRegionService: FakeVisitedRegionService(),
        );

        expect(controller.isFollowingUser, isTrue);

        controller.onCameraMoveStarted();
        expect(controller.isFollowingUser, isFalse);

        await controller.recenterOnUser();
        expect(controller.isFollowingUser, isTrue);

        controller.disposeController();
        controller.dispose();
      },
    );

    test('journey locations update the current map center', () {
      final controller = MapController(
        geoLocatorService: FakeGeoLocatorService(
          testPosition(-37.8136, 144.9631),
        ),
        visitService: RecordingVisitService(),
        visitedRegionService: FakeVisitedRegionService(),
      );

      const trackedLocation = LatLng(-37.8145, 144.9650);
      controller.followTrackedLocation(trackedLocation);

      expect(controller.center, trackedLocation);
      expect(controller.isFollowingUser, isTrue);

      controller.disposeController();
      controller.dispose();
    });
  });

  group('MapController.checkProximity', () {
    test('returns isNear true when within threshold', () async {
      // Same coordinates as [testPlace] so distance is effectively zero.
      final lat = -37.8136;
      final lng = 144.9631;
      final controller = MapController(
        geoLocatorService: FakeGeoLocatorService(testPosition(lat, lng)),
        visitService: RecordingVisitService(),
        visitedRegionService: FakeVisitedRegionService(),
      );

      final place = testPlace(location: testPlace().location);
      final result = await controller.checkProximity(place);

      expect(result.isNear, isTrue);
      expect(
        result.distance,
        lessThanOrEqualTo(MapController.visitProximityThreshold),
      );
      controller.disposeController();
      controller.dispose();
    });

    test('returns isNear false when beyond threshold', () async {
      final controller = MapController(
        geoLocatorService: FakeGeoLocatorService(testPosition(-30.0, 144.9631)),
        visitService: RecordingVisitService(),
        visitedRegionService: FakeVisitedRegionService(),
      );

      final place = testPlace();
      final result = await controller.checkProximity(place);

      expect(result.isNear, isFalse);
      expect(
        result.distance,
        greaterThan(MapController.visitProximityThreshold),
      );
      controller.disposeController();
      controller.dispose();
    });

    test('returns isNear false when location is unavailable', () async {
      final controller = MapController(
        geoLocatorService: FakeGeoLocatorService(
          testPosition(0, 0),
          throwOnGet: true,
        ),
        visitService: RecordingVisitService(),
        visitedRegionService: FakeVisitedRegionService(),
      );

      final result = await controller.checkProximity(testPlace());

      expect(result.isNear, isFalse);
      expect(result.distance, isNull);
      controller.disposeController();
      controller.dispose();
    });
  });

  group('MapController.markPlaceAsVisited', () {
    test('returns notLoggedIn when userId is unset', () async {
      final visitService = RecordingVisitService();
      final controller = MapController(
        geoLocatorService: FakeGeoLocatorService(
          testPosition(-37.8136, 144.9631),
        ),
        visitService: visitService,
        visitedRegionService: FakeVisitedRegionService(),
      );

      final result = await controller.markPlaceAsVisited(testPlace());

      expect(result, VisitResult.notLoggedIn);
      expect(visitService.markVisitedCallCount, 0);
      controller.disposeController();
      controller.dispose();
    });

    test('returns alreadyVisited when place is in visited set', () async {
      final visitService = RecordingVisitService(initialIds: {1});
      final controller = MapController(
        geoLocatorService: FakeGeoLocatorService(
          testPosition(-37.8136, 144.9631),
        ),
        visitService: visitService,
        visitedRegionService: FakeVisitedRegionService(),
      );

      await controller.setUserId('user-1');
      final result = await controller.markPlaceAsVisited(testPlace(id: 1));

      expect(result, VisitResult.alreadyVisited);
      expect(visitService.markVisitedCallCount, 0);
      controller.disposeController();
      controller.dispose();
    });

    test('returns tooFar when user is beyond proximity', () async {
      final visitService = RecordingVisitService();
      final controller = MapController(
        geoLocatorService: FakeGeoLocatorService(testPosition(-20.0, 144.9631)),
        visitService: visitService,
        visitedRegionService: FakeVisitedRegionService(),
      );

      await controller.setUserId('user-1');
      final result = await controller.markPlaceAsVisited(testPlace(id: 2));

      expect(result, VisitResult.tooFar);
      expect(visitService.markVisitedCallCount, 0);
      controller.disposeController();
      controller.dispose();
    });

    test('returns success and records visit when in range', () async {
      final visitService = RecordingVisitService();
      final controller = MapController(
        geoLocatorService: FakeGeoLocatorService(
          testPosition(-37.8136, 144.9631),
        ),
        visitService: visitService,
        visitedRegionService: FakeVisitedRegionService(),
      );

      await controller.setUserId('user-1');
      final place = testPlace(id: 42);
      final result = await controller.markPlaceAsVisited(place);

      expect(result, VisitResult.success);
      expect(visitService.markVisitedCallCount, 1);
      expect(controller.isPlaceVisited(42), isTrue);
      controller.disposeController();
      controller.dispose();
    });

    test('returns error when visit service throws', () async {
      final visitService = RecordingVisitService()
        ..markVisitedError = StateError('network');
      final controller = MapController(
        geoLocatorService: FakeGeoLocatorService(
          testPosition(-37.8136, 144.9631),
        ),
        visitService: visitService,
        visitedRegionService: FakeVisitedRegionService(),
      );

      await controller.setUserId('user-1');
      final result = await controller.markPlaceAsVisited(testPlace(id: 7));

      expect(result, VisitResult.error);
      controller.disposeController();
      controller.dispose();
    });
  });

  group('MapController.getPlaceById', () {
    test('returns null when cache is empty', () {
      final controller = MapController(
        visitService: RecordingVisitService(),
        visitedRegionService: FakeVisitedRegionService(),
      );

      expect(controller.getPlaceById(99), isNull);
      controller.disposeController();
      controller.dispose();
    });
  });

  group('MapController.toggleHeatmap', () {
    test('loads entry counts and enables heatmap when signed in', () async {
      final polygonService = _FakePolygonService(entryCounts: {'region-1': 3});
      final visitedRegionService = _FakeVisitedRegionService(
        regionIds: {'region-1'},
      );

      final controller = MapController(
        visitService: RecordingVisitService(),
        visitedRegionService: visitedRegionService,
        polygonService: polygonService,
      );

      await controller.setUserId('user-1');

      expect(controller.isHeatmapEnabled, isFalse);

      await controller.toggleHeatmap();

      expect(controller.isHeatmapEnabled, isTrue);
      expect(polygonService.getPolygonEntryCountsCalls, 1);
      expect(polygonService.lastProfileId, 'user-1');
      expect(polygonService.lastValidPolygonIds, {'region-1'});

      controller.disposeController();
      controller.dispose();
    });
  });
}
