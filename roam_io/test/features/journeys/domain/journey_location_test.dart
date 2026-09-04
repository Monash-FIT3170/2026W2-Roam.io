import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/journeys/domain/journey_location.dart';

void main() {
  test('custom location details round-trip through Firestore map data', () {
    const location = JourneyLocation(
      latLng: LatLng(-37.8136, 144.9631),
      displayName: 'Current Location',
      customName: 'Creek lookout',
      description: 'A quiet place near the trail.',
      mediaUrls: ['https://example.com/photo.jpg'],
    );

    expect(JourneyLocation.fromMap(location.toMap()), location);
  });

  test('older location data without custom details remains compatible', () {
    final location = JourneyLocation.fromMap({
      'latLng': {'latitude': -37.8136, 'longitude': 144.9631},
      'placeId': null,
      'displayName': 'Current Location',
      'customName': 'Old location',
    });

    expect(location.description, isNull);
    expect(location.mediaUrls, isEmpty);
  });
}
