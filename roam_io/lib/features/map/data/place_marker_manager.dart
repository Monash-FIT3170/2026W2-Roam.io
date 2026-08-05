import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'place_of_interest.dart';
import 'places_service.dart';

/*
 * Author: Rushil Patel
 * Description:
 *   Manages place-of-interest markers displayed on the map.
 *   Loads region places, creates Google Maps markers, tracks
 *   visited locations, and rebuilds marker visuals when zoom
 *   level or visit state changes.
 */

class PlaceMarkerManager {
  PlaceMarkerManager({PlacesService? placesService})
    : _placesService = placesService ?? PlacesService();

  final PlacesService _placesService;

  final Map<String, List<PlaceOfInterest>> _placesByRegionId = {};
  final Set<String> _loadingRegionIds = {};
  Set<int> _visitedPlaceIds = {};
  Set<String> _visibleRegionIds = {};
  void Function(PlaceOfInterest place)? _onPlaceTapped;

  Set<Marker> markers = {};

  void setVisitedPlaceIds(Set<int> visitedPlaceIds) {
    _visitedPlaceIds = visitedPlaceIds;
  }

  void setVisibleRegionIds(Set<String> regionIds) {
    _visibleRegionIds = Set<String>.from(regionIds);
    rebuildMarkers();
  }

  Future<void> loadPlacesForRegions({
    required Set<String> regionIds,
    required void Function(PlaceOfInterest place) onPlaceTapped,
  }) async {
    _onPlaceTapped = onPlaceTapped;
    final missingIds = regionIds
        .where(
          (regionId) =>
              !_placesByRegionId.containsKey(regionId) &&
              !_loadingRegionIds.contains(regionId),
        )
        .toList();

    _loadingRegionIds.addAll(missingIds);

    try {
      if (missingIds.isNotEmpty) {
        debugPrint(
          '[PlaceMarkerManager] Fetching places for '
          '${missingIds.length} visible regions',
        );
        final results = await _placesService.getPlacesForRegions(
          regionIds: missingIds,
        );
        for (final regionId in missingIds) {
          _placesByRegionId[regionId] = results[regionId] ?? const [];
        }
      }
    } finally {
      _loadingRegionIds.removeAll(missingIds);
    }
    rebuildMarkers();
  }

  Future<List<PlaceOfInterest>> loadPlacesForRegion({
    required String regionId,
    required void Function(PlaceOfInterest place) onPlaceTapped,
  }) async {
    _onPlaceTapped = onPlaceTapped;
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
    final didChange = PlaceOfInterest.updateSizeForZoom(zoom);

    if (didChange) {
      rebuildMarkers();
    }

    return didChange;
  }

  void rebuildMarkers({void Function(PlaceOfInterest place)? onPlaceTapped}) {
    if (onPlaceTapped != null) _onPlaceTapped = onPlaceTapped;
    final rebuiltMarkers = <Marker>{};

    for (final regionId in _visibleRegionIds) {
      final places = _placesByRegionId[regionId];
      if (places == null) continue;
      for (final place in places) {
        rebuiltMarkers.add(
          place.toMarker(
            visited: _visitedPlaceIds.contains(place.id),
            onTap: _onPlaceTapped,
          ),
        );
      }
    }

    markers = rebuiltMarkers;
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
