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

class _RecordingCameraAnimator {
  final List<CameraUpdate> updates = <CameraUpdate>[];
  final List<Duration?> durations = <Duration?>[];
  Object? error;

  Future<void> animate(CameraUpdate update, {Duration? duration}) async {
    final animationError = error;
    if (animationError != null) throw animationError;
    updates.add(update);
    durations.add(duration);
  }
}

Map<Object?, Object?> _cameraPositionFrom(CameraUpdate update) {
  final encoded = update.toJson() as List<Object?>;
  expect(encoded.first, 'newCameraPosition');
  return encoded[1]! as Map<Object?, Object?>;
}

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

  group('MapController device heading', () {
    test(
      'starts unavailable and exposes a normalized usable heading',
      () async {
        final controller = MapController(
          geoLocatorService: FakeGeoLocatorService(
            testPosition(-37.8136, 144.9631, heading: 725, headingAccuracy: 4),
          ),
          visitService: RecordingVisitService(),
          visitedRegionService: FakeVisitedRegionService(),
        );
        var listenerCalls = 0;
        controller.addListener(() => listenerCalls++);

        expect(controller.deviceHeading, isNull);

        await controller.recenterOnUser();

        expect(controller.deviceHeading, 5);
        expect(listenerCalls, 1);

        controller.disposeController();
        controller.dispose();
      },
    );

    test('ignores unavailable and invalid headings', () async {
      final invalidHeadings = <({double heading, double accuracy})>[
        (heading: 0, accuracy: 0),
        (heading: -1, accuracy: 5),
        (heading: double.nan, accuracy: 5),
        (heading: double.infinity, accuracy: 5),
        (heading: 45, accuracy: -1),
        (heading: 45, accuracy: double.nan),
      ];

      for (final value in invalidHeadings) {
        final controller = MapController(
          geoLocatorService: FakeGeoLocatorService(
            testPosition(
              -37.8136,
              144.9631,
              heading: value.heading,
              headingAccuracy: value.accuracy,
            ),
          ),
          visitService: RecordingVisitService(),
          visitedRegionService: FakeVisitedRegionService(),
        );
        var listenerCalls = 0;
        controller.addListener(() => listenerCalls++);

        await controller.recenterOnUser();

        expect(controller.deviceHeading, isNull);
        expect(listenerCalls, 0);
        expect(controller.isFollowingUser, isTrue);

        controller.disposeController();
        controller.dispose();
      }
    });

    test(
      'retains the latest usable heading and only notifies on changes',
      () async {
        final geoLocatorService = FakeGeoLocatorService(
          testPosition(-37.8136, 144.9631, heading: 90, headingAccuracy: 3),
        );
        final controller = MapController(
          geoLocatorService: geoLocatorService,
          visitService: RecordingVisitService(),
          visitedRegionService: FakeVisitedRegionService(),
        );
        var listenerCalls = 0;
        controller.addListener(() => listenerCalls++);

        await controller.getDistanceToPlace(testPlace());
        expect(controller.deviceHeading, 90);
        expect(listenerCalls, 1);

        geoLocatorService.setPosition(
          testPosition(-37.8136, 144.9631, heading: 90, headingAccuracy: 3),
        );
        await controller.getDistanceToPlace(testPlace());
        expect(listenerCalls, 1);

        geoLocatorService.setPosition(
          testPosition(-37.8136, 144.9631, heading: -1, headingAccuracy: -1),
        );
        await controller.getDistanceToPlace(testPlace());
        expect(controller.deviceHeading, 90);
        expect(listenerCalls, 1);

        geoLocatorService.setPosition(
          testPosition(-37.8136, 144.9631, heading: 120, headingAccuracy: 3),
        );
        await controller.getDistanceToPlace(testPlace());
        expect(controller.deviceHeading, 120);
        expect(listenerCalls, 2);

        controller.disposeController();
        controller.dispose();
      },
    );

    test(
      'enabling and disabling orientation preserves the camera position',
      () async {
        final animator = _RecordingCameraAnimator();
        final controller = MapController(
          geoLocatorService: FakeGeoLocatorService(
            testPosition(-37.8136, 144.9631, heading: 90, headingAccuracy: 3),
          ),
          cameraAnimator: animator.animate,
          visitService: RecordingVisitService(),
          visitedRegionService: FakeVisitedRegionService(),
        );
        const camera = CameraPosition(
          target: LatLng(-37.82, 144.97),
          zoom: 14.5,
          tilt: 12,
          bearing: 25,
        );
        controller.onCameraMove(camera);
        await controller.getDistanceToPlace(testPlace());

        await controller.setHeadingOrientationEnabled(true);

        expect(controller.isHeadingOrientationEnabled, isTrue);
        expect(animator.updates, hasLength(1));
        final headingCamera = _cameraPositionFrom(animator.updates.single);
        expect(headingCamera['target'], camera.target.toJson());
        expect(headingCamera['zoom'], camera.zoom);
        expect(headingCamera['tilt'], camera.tilt);
        expect(headingCamera['bearing'], 90);

        await controller.setHeadingOrientationEnabled(true);
        expect(animator.updates, hasLength(1));

        await controller.setHeadingOrientationEnabled(false);

        expect(controller.isHeadingOrientationEnabled, isFalse);
        expect(animator.updates, hasLength(2));
        final northUpCamera = _cameraPositionFrom(animator.updates.last);
        expect(northUpCamera['target'], camera.target.toJson());
        expect(northUpCamera['zoom'], camera.zoom);
        expect(northUpCamera['tilt'], camera.tilt);
        expect(northUpCamera['bearing'], 0);

        await controller.setHeadingOrientationEnabled(false);
        expect(animator.updates, hasLength(2));

        controller.disposeController();
        controller.dispose();
      },
    );

    test(
      'waits for heading and pauses bearing updates until recentered',
      () async {
        final animator = _RecordingCameraAnimator();
        final geoLocatorService = FakeGeoLocatorService(
          testPosition(-37.8136, 144.9631),
        );
        final controller = MapController(
          geoLocatorService: geoLocatorService,
          cameraAnimator: animator.animate,
          visitService: RecordingVisitService(),
          visitedRegionService: FakeVisitedRegionService(),
        );
        const camera = CameraPosition(target: LatLng(-37.82, 144.97), zoom: 15);
        controller.onCameraMove(camera);

        await controller.setHeadingOrientationEnabled(true);
        expect(controller.isHeadingOrientationEnabled, isTrue);
        expect(animator.updates, isEmpty);

        const trackedLocation = LatLng(-37.8136, 144.9631);
        controller.followTrackedLocation(trackedLocation);
        await Future<void>.delayed(Duration.zero);
        expect(animator.updates, hasLength(1));
        expect(animator.updates.single.toJson(), <Object>[
          'newLatLng',
          trackedLocation.toJson(),
        ]);

        geoLocatorService.setPosition(
          testPosition(
            trackedLocation.latitude,
            trackedLocation.longitude,
            heading: 45,
            headingAccuracy: 3,
          ),
        );
        await controller.getDistanceToPlace(testPlace());
        expect(animator.updates, hasLength(2));
        expect(_cameraPositionFrom(animator.updates.last)['bearing'], 45);

        controller.onCameraMoveStarted();
        await controller.onCameraIdle();
        controller.onCameraMoveStarted();
        expect(controller.isFollowingUser, isFalse);

        geoLocatorService.setPosition(
          testPosition(
            trackedLocation.latitude,
            trackedLocation.longitude,
            heading: 120,
            headingAccuracy: 3,
          ),
        );
        await controller.getDistanceToPlace(testPlace());
        expect(controller.deviceHeading, 120);
        expect(animator.updates, hasLength(2));

        await controller.recenterOnUser();

        expect(controller.isFollowingUser, isTrue);
        expect(animator.updates, hasLength(3));
        final recenteredCamera = _cameraPositionFrom(animator.updates.last);
        expect(recenteredCamera['target'], trackedLocation.toJson());
        expect(recenteredCamera['zoom'], camera.zoom);
        expect(recenteredCamera['bearing'], 120);

        controller.disposeController();
        controller.dispose();
      },
    );

    test('contains camera failures while changing heading mode', () async {
      final animator = _RecordingCameraAnimator()..error = StateError('failed');
      final controller = MapController(
        geoLocatorService: FakeGeoLocatorService(
          testPosition(-37.8136, 144.9631, heading: 90, headingAccuracy: 3),
        ),
        cameraAnimator: animator.animate,
        visitService: RecordingVisitService(),
        visitedRegionService: FakeVisitedRegionService(),
      );
      controller.onCameraMove(
        const CameraPosition(target: LatLng(-37.8136, 144.9631), zoom: 16),
      );
      await controller.getDistanceToPlace(testPlace());

      await controller.setHeadingOrientationEnabled(true);

      expect(controller.isHeadingOrientationEnabled, isTrue);

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
