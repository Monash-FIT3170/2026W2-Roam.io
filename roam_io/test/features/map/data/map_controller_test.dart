import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/data/map_controller.dart';

import '../../../support/map_test_doubles.dart';

void main() {
  group('MapController.checkProximity', () {
    test('returns isNear true when within threshold', () async {
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
      expect(result.distance, lessThanOrEqualTo(MapController.visitProximityThreshold));
      controller.disposeController();
      controller.dispose();
    });

    test('returns isNear false when beyond threshold', () async {
      final controller = MapController(
        geoLocatorService: FakeGeoLocatorService(
          testPosition(-30.0, 144.9631),
        ),
        visitService: RecordingVisitService(),
        visitedRegionService: FakeVisitedRegionService(),
      );

      final place = testPlace();
      final result = await controller.checkProximity(place);

      expect(result.isNear, isFalse);
      expect(result.distance, greaterThan(MapController.visitProximityThreshold));
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
        geoLocatorService: FakeGeoLocatorService(testPosition(-37.8136, 144.9631)),
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
        geoLocatorService: FakeGeoLocatorService(testPosition(-37.8136, 144.9631)),
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
      final regionService = FakeVisitedRegionService();
      final controller = MapController(
        geoLocatorService: FakeGeoLocatorService(testPosition(-37.8136, 144.9631)),
        visitService: visitService,
        visitedRegionService: regionService,
      );

      await controller.setUserId('user-1');
      final place = testPlace(id: 42);
      final result = await controller.markPlaceAsVisited(place);

      expect(result, VisitResult.success);
      expect(visitService.markVisitedCallCount, 1);
      expect(controller.isPlaceVisited(42), isTrue);
      expect(regionService.markVisitedCalls, 1);
      controller.disposeController();
      controller.dispose();
    });

    test('returns error when visit service throws', () async {
      final visitService = RecordingVisitService()
        ..markVisitedError = StateError('network');
      final controller = MapController(
        geoLocatorService: FakeGeoLocatorService(testPosition(-37.8136, 144.9631)),
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
}
