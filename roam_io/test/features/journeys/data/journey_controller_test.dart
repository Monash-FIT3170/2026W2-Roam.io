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
import 'package:roam_io/features/map/data/geolocator_service.dart';

void main() {
  test(
    'tile unlock XP is counted only while journey tracking is active',
    () async {
      final geo = _StreamingGeoLocatorService();
      final controller = JourneyController(
        journeyService: JourneyService(firestore: FakeFirebaseFirestore()),
        trackingService: JourneyTrackingService(geoLocatorService: geo),
      );

      controller.recordTileUnlocked(50);
      expect(controller.tilesUnlocked, 0);

      controller.beginJourneySetup();
      controller.setStartLocation(
        const JourneyLocation(
          latLng: LatLng(-37.8136, 144.9631),
          displayName: 'Start',
        ),
      );
      await controller.startTracking();

      controller.recordTileUnlocked(50);
      controller.recordTileUnlocked(50);

      expect(controller.tilesUnlocked, 2);
      expect(controller.tileXpEarned, 100);
      expect(controller.totalXpEarned, controller.journeyXpEarned + 100);

      await controller.stopTracking();
      controller.recordTileUnlocked(50);
      expect(controller.tilesUnlocked, 2);

      await controller.cancelJourney();
      controller.dispose();
      await geo.dispose();
    },
  );

  test(
    'continuing an ended journey resumes and preserves its progress',
    () async {
      final geo = _StreamingGeoLocatorService();
      final trackingService = JourneyTrackingService(geoLocatorService: geo);
      final controller = JourneyController(
        journeyService: JourneyService(firestore: FakeFirebaseFirestore()),
        trackingService: trackingService,
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
