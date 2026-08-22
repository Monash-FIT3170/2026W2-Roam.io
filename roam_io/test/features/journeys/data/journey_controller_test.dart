import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/journeys/data/journey_controller.dart';
import 'package:roam_io/features/journeys/data/journey_service.dart';
import 'package:roam_io/features/journeys/data/journey_tracking_service.dart';
import 'package:roam_io/features/journeys/domain/journey_location.dart';
import 'package:roam_io/features/journeys/domain/journey_phase.dart';
import 'package:roam_io/features/journeys/domain/transport_mode.dart';
import 'package:roam_io/features/map/data/geolocator_service.dart';
import 'package:roam_io/notifications/services/live_activity_service.dart';

void main() {
  test(
    'tile unlock XP is counted only while journey tracking is active',
    () async {
      final firestore = FakeFirebaseFirestore();
      final geo = _StreamingGeoLocatorService();
      final liveActivity = _FakeLiveActivityGateway();
      final controller = JourneyController(
        journeyService: JourneyService(firestore: firestore),
        trackingService: JourneyTrackingService(geoLocatorService: geo),
        liveActivityService: liveActivity,
      );

      controller.recordTileUnlocked(polygonId: 'tile-1', xpAwarded: 50);
      expect(controller.tilesUnlocked, 0);

      controller.beginJourneySetup();
      controller.setStartLocation(
        const JourneyLocation(
          latLng: LatLng(-37.8136, 144.9631),
          displayName: 'Start',
        ),
      );
      await controller.startTracking();

      controller.recordTileUnlocked(polygonId: 'tile-1', xpAwarded: 50);
      controller.recordTileUnlocked(polygonId: 'tile-2', xpAwarded: 50);
      await Future<void>.delayed(Duration.zero);

      expect(controller.tilesUnlocked, 2);
      expect(controller.tileXpEarned, 100);
      expect(controller.totalXpEarned, controller.journeyXpEarned + 100);
      expect(liveActivity.started, hasLength(1));
      expect(liveActivity.updated.last.tilesUnlocked, 2);
      expect(liveActivity.updated.last.xpEarned, controller.totalXpEarned);

      await controller.stopTracking();
      controller.recordTileUnlocked(polygonId: 'tile-1', xpAwarded: 50);
      expect(controller.tilesUnlocked, 2);
      expect(liveActivity.stopped, hasLength(1));

      await controller.cancelJourney();
      controller.dispose();
      await liveActivity.dispose();
      await geo.dispose();
    },
  );

  test('completes, saves, reads, updates, and deletes a journey', () async {
    final firestore = FakeFirebaseFirestore();
    final service = JourneyService(firestore: firestore);
    final geo = _StreamingGeoLocatorService();
    final liveActivity = _FakeLiveActivityGateway();
    final controller = JourneyController(
      journeyService: service,
      trackingService: JourneyTrackingService(geoLocatorService: geo),
      liveActivityService: liveActivity,
    );
    const start = JourneyLocation(
      latLng: LatLng(-37.8136, 144.9631),
      displayName: 'Start',
    );
    const end = JourneyLocation(
      latLng: LatLng(-37.8115, 144.9631),
      displayName: 'End',
    );

    controller.beginJourneySetup();
    controller.setStartLocation(start);
    controller.setTransportMode(TransportMode.drive);
    await controller.startTracking();
    geo.addPosition(-37.8125, 144.9631);
    await Future<void>.delayed(Duration.zero);
    controller.recordTileUnlocked(
      polygonId: 'tile-save',
      xpAwarded: 50,
      areaSquareMetres: 1000,
    );
    await controller.stopTracking();
    controller.setEndLocation(end);
    controller.proceedToReview();
    controller.updateStartLocationName('Home');
    controller.updateEndLocationName('Work');

    expect(controller.currentPhase, JourneyPhase.reviewing);
    expect(controller.formattedDistance, endsWith('m'));
    expect(controller.formattedElapsedTime, isNotEmpty);
    expect(controller.startLocation?.name, 'Home');
    expect(controller.endLocation?.name, 'Work');

    final saved = await controller.saveJourney('user-1');

    expect(saved, isNotNull);
    expect(saved!.xpEarned, saved.journeyXpEarned! + 50);
    expect(saved.tilesUnlocked, 1);
    expect(saved.unlockedTileIds, ['tile-save']);
    expect(saved.areaUnlockedSquareMetres, 1000);
    expect(controller.currentPhase, JourneyPhase.idle);

    final journeys = await controller.getJourneys('user-1');
    expect(journeys, hasLength(1));
    expect(await controller.getJourneysStream('user-1').first, hasLength(1));

    const renamed = JourneyLocation(
      latLng: LatLng(-37.8136, 144.9631),
      displayName: 'Renamed Home',
    );
    await controller.updateSavedLocation(
      userId: 'user-1',
      journeyId: saved.id,
      isStartLocation: true,
      location: renamed,
    );
    expect(
      (await controller.getJourneys('user-1')).single.startLocation,
      renamed,
    );

    await controller.deleteJourney(userId: 'user-1', journeyId: saved.id);
    expect(await controller.getJourneys('user-1'), isEmpty);

    controller.dispose();
    await liveActivity.dispose();
    await geo.dispose();
  });

  test(
    'can persist a reviewed journey without resetting for publish retry',
    () async {
      final firestore = FakeFirebaseFirestore();
      final service = JourneyService(firestore: firestore);
      final geo = _StreamingGeoLocatorService();
      final liveActivity = _FakeLiveActivityGateway();
      final controller = JourneyController(
        journeyService: service,
        trackingService: JourneyTrackingService(geoLocatorService: geo),
        liveActivityService: liveActivity,
      );

      controller.beginJourneySetup();
      controller.setStartLocation(
        const JourneyLocation(
          latLng: LatLng(-37.8136, 144.9631),
          displayName: 'Start',
        ),
      );
      await controller.startTracking();
      geo.addPosition(-37.8125, 144.9631);
      await Future<void>.delayed(Duration.zero);
      await controller.stopTracking();
      controller.setEndLocation(
        const JourneyLocation(
          latLng: LatLng(-37.8115, 144.9631),
          displayName: 'End',
        ),
      );
      controller.proceedToReview();

      final first = await controller.saveJourney(
        'user-1',
        title: 'Morning Journey',
        resetAfterSave: false,
      );
      final second = await controller.saveJourney(
        'user-1',
        title: 'Renamed Journey',
        resetAfterSave: false,
      );

      expect(first, isNotNull);
      expect(second?.id, first?.id);
      expect(second?.title, 'Renamed Journey');
      expect(controller.currentPhase, JourneyPhase.reviewing);
      expect(controller.persistedReviewedJourney?.id, first?.id);
      expect(controller.reviewedJourneyXpAwarded, isFalse);
      controller.markReviewedJourneyXpAwarded();
      expect(controller.reviewedJourneyXpAwarded, isTrue);

      final journeys = await controller.getJourneys('user-1');
      expect(journeys, hasLength(1));
      expect(journeys.single.title, 'Renamed Journey');

      controller.clearReviewedJourney();
      expect(controller.currentPhase, JourneyPhase.idle);

      controller.dispose();
      await liveActivity.dispose();
      await geo.dispose();
    },
  );

  test('rejects invalid state transitions and incomplete journeys', () async {
    final firestore = FakeFirebaseFirestore();
    final geo = _StreamingGeoLocatorService();
    final liveActivity = _FakeLiveActivityGateway();
    final controller = JourneyController(
      journeyService: JourneyService(firestore: firestore),
      trackingService: JourneyTrackingService(geoLocatorService: geo),
      liveActivityService: liveActivity,
    );

    await controller.stopTracking();
    await controller.pauseTracking();
    await controller.resumeTracking();
    controller.proceedToReview();
    expect(await controller.saveJourney('user-1'), isNull);

    controller.beginJourneySetup();
    controller.beginJourneySetup();
    await controller.startTracking();
    expect(controller.errorMessage, 'Please select a start location');

    controller.updateStartLocation(
      const JourneyLocation(latLng: LatLng(0, 0), displayName: 'Updated Start'),
    );
    controller.updateEndLocation(
      const JourneyLocation(latLng: LatLng(0, 0), displayName: 'Updated End'),
    );
    controller.updateStartLocationName('');
    controller.updateEndLocationName('');

    expect(controller.startLocation?.customName, isNull);
    expect(controller.endLocation?.customName, isNull);

    await controller.cancelJourney();
    controller.dispose();
    await liveActivity.dispose();
    await geo.dispose();
  });

  test(
    'continuing an ended journey resumes and preserves its progress',
    () async {
      final firestore = FakeFirebaseFirestore();
      final geo = _StreamingGeoLocatorService();
      final trackingService = JourneyTrackingService(geoLocatorService: geo);
      final liveActivity = _FakeLiveActivityGateway();
      final controller = JourneyController(
        journeyService: JourneyService(firestore: firestore),
        trackingService: trackingService,
        liveActivityService: liveActivity,
      );

      controller.beginJourneySetup();
      controller.setStartLocation(
        const JourneyLocation(
          latLng: LatLng(-37.8136, 144.9631),
          displayName: 'Start',
        ),
      );
      await controller.startTracking();

      geo.addPosition(-37.8126, 144.9631);
      await Future<void>.delayed(Duration.zero);
      await controller.stopTracking();

      final startTime = controller.startTime;
      final pointsBeforeResume = controller.routePoints;
      final distanceBeforeResume = controller.distanceMeters;
      expect(controller.currentPhase, JourneyPhase.completing);
      expect(controller.endTime, isNotNull);

      await controller.resumeTracking();

      expect(controller.currentPhase, JourneyPhase.tracking);
      expect(controller.startTime, startTime);
      expect(controller.endTime, isNull);
      expect(controller.routePoints, pointsBeforeResume);
      expect(controller.distanceMeters, distanceBeforeResume);
      expect(trackingService.isTracking, isTrue);
      expect(liveActivity.started, hasLength(2));

      geo.addPosition(-37.8116, 144.9631);
      await Future<void>.delayed(Duration.zero);

      expect(controller.routePoints.length, pointsBeforeResume.length + 1);
      expect(controller.distanceMeters, greaterThan(distanceBeforeResume));

      await controller.cancelJourney();
      controller.dispose();
      await liveActivity.dispose();
      await geo.dispose();
    },
  );

  test('pauses and resumes a live journey without losing progress', () async {
    final geo = _StreamingGeoLocatorService();
    final trackingService = JourneyTrackingService(geoLocatorService: geo);
    final liveActivity = _FakeLiveActivityGateway();
    final controller = JourneyController(
      journeyService: JourneyService(firestore: FakeFirebaseFirestore()),
      trackingService: trackingService,
      liveActivityService: liveActivity,
    );

    controller.beginJourneySetup();
    controller.setStartLocation(
      const JourneyLocation(
        latLng: LatLng(-37.8136, 144.9631),
        displayName: 'Start',
      ),
    );
    await controller.startTracking();

    geo.addPosition(-37.8126, 144.9631);
    await Future<void>.delayed(Duration.zero);
    final distanceBeforePause = controller.distanceMeters;
    final pointsBeforePause = controller.routePoints.length;

    await controller.pauseTracking();

    expect(controller.currentPhase, JourneyPhase.paused);
    expect(controller.isPaused, isTrue);
    expect(trackingService.isTracking, isFalse);
    expect(liveActivity.paused, hasLength(1));
    expect(liveActivity.paused.single.isPaused, isTrue);

    // Broadcast GPS updates are ignored because the tracking subscription has
    // been cancelled while paused.
    geo.addPosition(-37.8116, 144.9631);
    await Future<void>.delayed(Duration.zero);
    expect(controller.distanceMeters, distanceBeforePause);
    expect(controller.routePoints, hasLength(pointsBeforePause));

    await controller.resumeTracking();

    expect(controller.currentPhase, JourneyPhase.tracking);
    expect(controller.isPaused, isFalse);
    expect(trackingService.isTracking, isTrue);
    expect(liveActivity.resumed, hasLength(1));
    expect(liveActivity.resumed.single.isPaused, isFalse);

    geo.addPosition(-37.8116, 144.9631);
    await Future<void>.delayed(Duration.zero);
    expect(controller.distanceMeters, greaterThan(distanceBeforePause));

    await controller.cancelJourney();
    controller.dispose();
    await liveActivity.dispose();
    await geo.dispose();
  });

  test('live notification actions control the JourneyController', () async {
    final geo = _StreamingGeoLocatorService();
    final liveActivity = _FakeLiveActivityGateway();
    final controller = JourneyController(
      journeyService: JourneyService(firestore: FakeFirebaseFirestore()),
      trackingService: JourneyTrackingService(geoLocatorService: geo),
      liveActivityService: liveActivity,
    );

    controller.beginJourneySetup();
    controller.setStartLocation(
      const JourneyLocation(
        latLng: LatLng(-37.8136, 144.9631),
        displayName: 'Start',
      ),
    );
    await controller.startTracking();

    liveActivity.emit(LiveActivityAction.pause);
    await Future<void>.delayed(Duration.zero);
    expect(controller.currentPhase, JourneyPhase.paused);

    liveActivity.emit(LiveActivityAction.resume);
    await Future<void>.delayed(Duration.zero);
    expect(controller.currentPhase, JourneyPhase.tracking);

    liveActivity.emit(LiveActivityAction.stop);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(controller.currentPhase, JourneyPhase.completing);

    controller.dispose();
    await liveActivity.dispose();
    await geo.dispose();
  });
}

class _StreamingGeoLocatorService extends GeoLocatorService {
  final StreamController<Position> _positions =
      StreamController<Position>.broadcast();

  @override
  Future<Stream<Position>> getLocationUpdates({
    bool allowBackgroundUpdates = false,
  }) async => _positions.stream;

  void addPosition(double latitude, double longitude) {
    _positions.add(
      Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime(2026),
        accuracy: 1,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ),
    );
  }

  Future<void> dispose() => _positions.close();
}

class _FakeLiveActivityGateway implements LiveActivityGateway {
  final StreamController<LiveActivityAction> _actions =
      StreamController<LiveActivityAction>.broadcast();

  final List<LiveJourneyState> started = [];
  final List<LiveJourneyState> updated = [];
  final List<LiveJourneyState> paused = [];
  final List<LiveJourneyState> resumed = [];
  final List<LiveJourneyState> stopped = [];

  @override
  Stream<LiveActivityAction> get actions => _actions.stream;

  @override
  Future<bool> get isSupported async => true;

  @override
  Future<void> startJourney(LiveJourneyState state) async {
    started.add(state);
  }

  @override
  Future<void> updateJourney(LiveJourneyState state) async {
    updated.add(state);
  }

  @override
  Future<void> pauseJourney(LiveJourneyState state) async {
    paused.add(state);
  }

  @override
  Future<void> resumeJourney(LiveJourneyState state) async {
    resumed.add(state);
  }

  @override
  Future<void> stopJourney(LiveJourneyState state) async {
    stopped.add(state);
  }

  void emit(LiveActivityAction action) {
    _actions.add(action);
  }

  Future<void> dispose() => _actions.close();
}
