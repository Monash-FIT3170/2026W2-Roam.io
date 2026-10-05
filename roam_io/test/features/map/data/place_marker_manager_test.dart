import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/map/data/place_marker_manager.dart';
import 'package:roam_io/features/map/data/place_of_interest.dart';
import 'package:roam_io/features/map/data/places_service.dart';

void main() {
  test(
    'range updates use visible locations and preserve visited state',
    () async {
      final manager = PlaceMarkerManager(
        placesService: _FakePlacesService({
          'a': [_place(1, 'a')],
          'b': [_place(2, 'b')],
        }),
      );
      manager.setVisibleRegionIds({'a'});
      await manager.loadPlacesForRegions(
        regionIds: {'a'},
        onPlaceTapped: (_) {},
      );
      final unvisited = manager.markers.single.icon.toJson();
      manager.updateUserLocation(const LatLng(-37.81, 144.96));
      expect(manager.markers.single.icon.toJson(), isNot(unvisited));
      expect(manager.markers.single.zIndexInt, 3);
      final sameState = manager.markers;
      manager.updateUserLocation(const LatLng(-37.81001, 144.96));
      expect(identical(manager.markers, sameState), isTrue);
      manager.updateUserLocation(const LatLng(-38, 145));
      expect(manager.markers.single.icon.toJson(), unvisited);
      manager.updateUserLocation(null);
      expect(manager.markers.single.icon.toJson(), unvisited);
      final visitedIds = {1};
      manager.setVisitedPlaceIds(visitedIds);
      visitedIds.clear();
      manager.rebuildMarkers();
      final visited = manager.markers.single.icon.toJson();
      expect(visited, isNot(unvisited));
      manager.updateUserLocation(const LatLng(-37.81, 144.96));
      expect(manager.markers.single.icon.toJson(), visited);
      expect(manager.markers.single.zIndexInt, 1);
      manager.setVisibleRegionIds({'b'});
      await manager.loadPlacesForRegions(
        regionIds: {'b'},
        onPlaceTapped: (_) {},
      );
      expect(manager.markers.single.markerId.value, 'place_2');
      expect(manager.markers.single.zIndexInt, 3);
    },
  );

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
