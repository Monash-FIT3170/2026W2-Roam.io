import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/journeys/domain/nearby_place.dart';
import 'package:roam_io/features/journeys/domain/transport_mode.dart';

void main() {
  test('maps Google transport place types to journey modes', () {
    const place = NearbyPlace(
      name: 'Transport interchange',
      address: '',
      latLng: LatLng(-37.81, 144.96),
      distanceMeters: 25,
      types: ['bus_stop', 'train_station', 'tram_stop'],
    );

    expect(place.supportedTransportModes, {
      TransportMode.bus,
      TransportMode.train,
      TransportMode.tram,
    });
  });
}
