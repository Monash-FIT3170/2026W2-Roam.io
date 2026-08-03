import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roam_io/features/map/data/places_service.dart';

void main() {
  test('getNearbyPlaces returns nearest places first', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode([
          _place('far', 9),
          _place('unknown', null),
          _place('nearest', 2),
          _place('middle', 5),
        ]),
        200,
      );
    });

    final places = await PlacesService(
      client: client,
    ).getNearbyPlaces(lat: -38, lng: 145);

    expect(places.map((place) => place.name), [
      'nearest',
      'middle',
      'far',
      'unknown',
    ]);
  });
}

Map<String, Object?> _place(String name, int? distanceMeters) => {
  'placeId': name,
  'name': name,
  'address': '',
  'location': {'lat': -38.0, 'lng': 145.0},
  'distanceMeters': distanceMeters,
};
