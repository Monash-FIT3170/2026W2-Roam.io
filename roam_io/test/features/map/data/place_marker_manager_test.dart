import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/map/data/place_marker_manager.dart';
import 'package:roam_io/features/map/data/place_of_interest.dart';
import 'package:roam_io/features/map/data/places_service.dart';

void main() {
  test('renders only visible regions and reuses cached place data', () async {
    final service = _FakePlacesService({
      'a': [_place(1, 'a')],
      'b': [_place(2, 'b')],
    });
    final manager = PlaceMarkerManager(placesService: service);

    manager.setVisibleRegionIds({'a'});
    await manager.loadPlacesForRegions(regionIds: {'a'}, onPlaceTapped: (_) {});
    expect(manager.markers.map((marker) => marker.markerId.value), ['place_1']);

    manager.setVisibleRegionIds({'b'});
    await manager.loadPlacesForRegions(regionIds: {'b'}, onPlaceTapped: (_) {});
    expect(manager.markers.map((marker) => marker.markerId.value), ['place_2']);

    manager.setVisibleRegionIds({'a'});
    await manager.loadPlacesForRegions(regionIds: {'a'}, onPlaceTapped: (_) {});
    expect(manager.markers.map((marker) => marker.markerId.value), ['place_1']);
    expect(service.requestedRegionBatches, [
      ['a'],
      ['b'],
    ]);
  });
}

PlaceOfInterest _place(int id, String regionId) => PlaceOfInterest(
  id: id,
  googlePlaceId: 'google-$id',
  name: 'Place $id',
  category: PlaceCategory.other,
  types: const [],
  location: const LatLng(-37.81, 144.96),
  regionId: regionId,
);

class _FakePlacesService extends PlacesService {
  _FakePlacesService(this.placesByRegion);

  final Map<String, List<PlaceOfInterest>> placesByRegion;
  final List<List<String>> requestedRegionBatches = [];

  @override
  Future<Map<String, List<PlaceOfInterest>>> getPlacesForRegions({
    required List<String> regionIds,
  }) async {
    requestedRegionBatches.add(List<String>.from(regionIds));
    return {
      for (final regionId in regionIds)
        regionId: placesByRegion[regionId] ?? const [],
    };
  }
}
