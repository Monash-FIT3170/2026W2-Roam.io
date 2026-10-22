import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/map/data/place_of_interest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all sizes and transport types have distinct status artwork', () async {
    await PlaceOfInterest.preloadIcons();
    for (final zoom in [12.0, 14.0, 17.0]) {
      PlaceOfInterest.updateSizeForZoom(zoom);
      for (final type in ['', 'train_station', 'tram_stop', 'bus_stop']) {
        final place = PlaceOfInterest(
          id: 1,
          googlePlaceId: 'one',
          name: 'Place',
          category: PlaceCategory.other,
          types: [type],
          location: const LatLng(-37.81, 144.96),
          regionId: 'a',
        );
        final normal = place.toMarker();
        final nearby = place.toMarker(inRange: true);
        final visited = place.toMarker(visited: true);
        expect(normal.icon, isA<BytesMapBitmap>());
        expect(nearby.icon.toJson(), isNot(equals(normal.icon.toJson())));
        expect(visited.icon.toJson(), isNot(equals(normal.icon.toJson())));
        expect(visited.icon.toJson(), isNot(equals(nearby.icon.toJson())));
        expect(place.toMarker(visited: true, inRange: true).icon, visited.icon);
        expect(normal.anchor, const Offset(.5, .5));
        var taps = 0;
        place
            .toMarker(
              onTap: (selected) {
                expect(selected, place);
                taps++;
              },
            )
            .onTap!();
        expect(taps, 1);
      }
    }
    PlaceOfInterest.updateSizeForZoom(14);
  });

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
