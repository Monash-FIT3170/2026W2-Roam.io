import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/map/data/place_of_interest.dart';

void main() {
  test('maps backend public transport places to the transit category', () {
    final category = PlaceCategory.fromString('public_transport');

    expect(category, PlaceCategory.publicTransport);
    expect(category.displayName, 'Public Transport');
  });

  test('selects the correct marker artwork from Google place types', () {
    PlaceOfInterest placeWithTypes(List<String> types) => PlaceOfInterest(
      id: 1,
      googlePlaceId: 'google-id',
      name: 'Stop',
      category: PlaceCategory.publicTransport,
      types: types,
      location: const LatLng(-37.81, 144.96),
      regionId: 'region',
    );

    expect(
      placeWithTypes(['train_station']).transportMarkerType,
      TransportMarkerType.train,
    );
    expect(
      placeWithTypes(['bus_stop']).transportMarkerType,
      TransportMarkerType.bus,
    );
    expect(
      placeWithTypes(['tram_stop']).transportMarkerType,
      TransportMarkerType.tram,
    );
  });
}
