import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'place_of_interest.dart';
import 'places_service.dart';

class PlaceMarkerManager {
  PlaceMarkerManager({
    PlacesService? placesService,
  }) : _placesService = placesService ?? PlacesService();

  final PlacesService _placesService;

  final Map<String, List<PlaceOfInterest>> _placesByRegionId = {};
  Set<int> _visitedPlaceIds = {};

  Set<Marker> markers = {};

  void setVisitedPlaceIds(Set<int> visitedPlaceIds) {
    _visitedPlaceIds = visitedPlaceIds;
    rebuildMarkers();
  }

  Future<List<PlaceOfInterest>> loadPlacesForRegion({
    required String regionId,
    required void Function(PlaceOfInterest place) onPlaceTapped,
  }) async {
    if (_placesByRegionId.containsKey(regionId)) {
      rebuildMarkers(onPlaceTapped: onPlaceTapped);
      return _placesByRegionId[regionId]!;
    }

    debugPrint('[PlaceMarkerManager] Fetching places for $regionId');

    final places = await _placesService.getPlacesForRegion(regionId: regionId);

    _placesByRegionId[regionId] = places;
    rebuildMarkers(onPlaceTapped: onPlaceTapped);

    return places;
  }

  bool updateMarkerSizeForZoom(double zoom) {
    final sizeChanged = PlaceOfInterest.updateSizeForZoom(zoom);

    if (sizeChanged) {
      rebuildMarkers();
    }

    return sizeChanged;
  }

  void rebuildMarkers({
    void Function(PlaceOfInterest place)? onPlaceTapped,
  }) {
    final allMarkers = <Marker>{};

    for (final places in _placesByRegionId.values) {
      for (final place in places) {
        allMarkers.add(
          place.toMarker(
            visited: _visitedPlaceIds.contains(place.id),
            onTap: onPlaceTapped,
          ),
        );
      }
    }

    markers = allMarkers;
  }

  PlaceOfInterest? getPlaceById(int placeId) {
    for (final places in _placesByRegionId.values) {
      for (final place in places) {
        if (place.id == placeId) return place;
      }
    }

    return null;
  }
}