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
import 'package:roam_io/features/you/services/stats_summary_service.dart';

void main() {
  test(
    'tile unlock XP is counted only while journey tracking is active',
    () async {
      final geo = _StreamingGeoLocatorService();
      final firestore = FakeFirebaseFirestore();
      final controller = JourneyController(
        journeyService: JourneyService(firestore: firestore),
        trackingService: JourneyTrackingService(geoLocatorService: geo),
        statsSummaryService: StatsSummaryService(firestore: firestore),
      );

      controller.recordTileUnlocked(
        polygonId: 'tile-1',
        xpAwarded: 50,
      );
      expect(controller.tilesUnlocked, 0);

      controller.beginJourneySetup();
      controller.setStartLocation(
        const JourneyLocation(
          latLng: LatLng(-37.8136, 144.9631),
          displayName: 'Start',
        ),
      );
      await controller.startTracking();

      controller.recordTileUnlocked(
        polygonId: 'tile-1',
        xpAwarded: 50,
      );
      controller.recordTileUnlocked(
        polygonId: 'tile-2',
        xpAwarded: 50,
      );

      expect(controller.tilesUnlocked, 2);
      expect(controller.tileXpEarned, 100);
      expect(controller.totalXpEarned, controller.journeyXpEarned + 100);

      await controller.stopTracking();
      controller.recordTileUnlocked(
        polygonId: 'tile-1',
        xpAwarded: 50,
      );
      expect(controller.tilesUnlocked, 2);

      await controller.cancelJourney();
      controller.dispose();
      await geo.dispose();
    },
  );

  test('completes, saves, reads, updates, and deletes a journey', () async {
    final firestore = FakeFirebaseFirestore();
    final service = JourneyService(firestore: firestore);
    final geo = _StreamingGeoLocatorService();
    final controller = JourneyController(
      journeyService: service,
      trackingService: JourneyTrackingService(geoLocatorService: geo),
      statsSummaryService: StatsSummaryService(firestore: firestore),
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
    expect(saved?.xpEarned, saved!.journeyXpEarned! + 50);
    expect(saved?.tilesUnlocked, 1);
    expect(saved?.unlockedTileIds, ['tile-save']);
    expect(saved?.areaUnlockedSquareMetres, 1000);
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
    await geo.dispose();
  });

  test('rejects invalid state transitions and incomplete journeys', () async {
    final geo = _StreamingGeoLocatorService();
    final firestore = FakeFirebaseFirestore();
    final controller = JourneyController(
      journeyService: JourneyService(firestore: firestore),
      trackingService: JourneyTrackingService(geoLocatorService: geo),
      statsSummaryService: StatsSummaryService(firestore: firestore),
    );

    await controller.stopTracking();
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
    await geo.dispose();
  });

  test(
    'continuing an ended journey resumes and preserves its progress',
    () async {
      final geo = _StreamingGeoLocatorService();
      final trackingService = JourneyTrackingService(geoLocatorService: geo);
      final firestore = FakeFirebaseFirestore();
      final controller = JourneyController(
        journeyService: JourneyService(firestore: firestore),
        trackingService: trackingService,
        statsSummaryService: StatsSummaryService(firestore: firestore),
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

      geo.addPosition(-37.8116, 144.9631);
      await Future<void>.delayed(Duration.zero);

      expect(controller.routePoints.length, pointsBeforeResume.length + 1);
      expect(controller.distanceMeters, greaterThan(distanceBeforeResume));

      await controller.cancelJourney();
      controller.dispose();
      await geo.dispose();
    },
  );
}

class _StreamingGeoLocatorService extends GeoLocatorService {
  final StreamController<Position> _positions =
      StreamController<Position>.broadcast();

  @override
  Future<Stream<Position>> getLocationUpdates() async => _positions.stream;

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
