import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/journeys/domain/journey.dart';
import 'package:roam_io/features/journeys/domain/journey_location.dart';
import 'package:roam_io/features/journeys/domain/transport_mode.dart';

void main() {
  test('displayTitle uses both custom location names', () {
    final journey = _journey(
      startLocation: const JourneyLocation(
        latLng: LatLng(-37.81, 144.96),
        displayName: 'Starting address',
        customName: 'Home',
      ),
      endLocation: const JourneyLocation(
        latLng: LatLng(-37.82, 144.97),
        displayName: 'Destination address',
        customName: 'Work',
      ),
    );

    expect(journey.displayTitle, 'Home to Work');
  });

  test('displayTitle falls back to each location display name', () {
    final journey = _journey(
      startLocation: const JourneyLocation(
        latLng: LatLng(-37.81, 144.96),
        displayName: 'Home',
      ),
      endLocation: const JourneyLocation(
        latLng: LatLng(-37.82, 144.97),
        displayName: 'Tennis',
      ),
    );

    expect(journey.displayTitle, 'Home to Tennis');
  });
}

Journey _journey({
  required JourneyLocation startLocation,
  required JourneyLocation endLocation,
}) {
  return Journey(
    id: 'journey-1',
    userId: 'user-1',
    startTime: DateTime(2026, 8, 5, 9),
    endTime: DateTime(2026, 8, 5, 10),
    startLocation: startLocation,
    endLocation: endLocation,
    transportMode: TransportMode.walk,
    encodedRoute: '',
    distanceMeters: 1000,
    durationSeconds: 3600,
  );
}
