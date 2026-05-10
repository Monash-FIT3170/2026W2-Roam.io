/*
 * Author: Amarprit Singh
 * Last Modified: 10/05/2026
 * Description:
 *
 *   Coordinates map state, region loading, live location updates, place
 *   markers, and visited styling in one controller so the widgets can stay
 *   focused on rendering.
 *
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'Place_of_interest.dart';
import 'places_service.dart';
import 'visit_service.dart';
import 'geolocator_service.dart';
import 'region_polygon.dart';
import 'region_polygon_cache.dart';
import 'region_service.dart';
import 'visited_region_service.dart';

/// Result of attempting to mark a place as visited.
enum VisitResult { success, notLoggedIn, alreadyVisited, tooFar, error }

class MapController extends ChangeNotifier {
  static const LatLng fallbackCenter = LatLng(-37.8136, 144.9631);
  static const double defaultZoom = 13.5;
  static const double visitProximityThreshold = 100.0;

  static const String _visitedTilesStyleAsset =
      'assets/map_styles/visited_tiles.json';

  final GeoLocatorService _geoLocatorService;
  final RegionService _regionService;
  final VisitedRegionService _visitedRegionService;
  final RegionPolygonCache _polygonCacheManager;
  final PlacesService _placesService;
  final VisitService _visitService;

  MapController({
    GeoLocatorService? geoLocatorService,
    RegionService? regionService,
    VisitedRegionService? visitedRegionService,
    RegionPolygonCache? polygonCacheManager,
    PlacesService? placesService,
    VisitService? visitService,
  }) : _geoLocatorService = geoLocatorService ?? GeoLocatorService(),
       _regionService = regionService ?? RegionService(),
       _visitedRegionService = visitedRegionService ?? VisitedRegionService(),
       _polygonCacheManager = polygonCacheManager ?? RegionPolygonCache(),
       _placesService = placesService ?? PlacesService(),
       _visitService = visitService ?? VisitService();

  GoogleMapController? _googleMapController;
  StreamSubscription<Position>? _locationSubscription;

  LatLng center = fallbackCenter;
  String? mapStyle;
  bool myLocationEnabled = false;
  bool isLoading = true;
  bool isLoadingViewport = false;
  bool isLoadingPlaces = false;
  String? message;

  String? _userId;
  Set<String> visitedPolygonIds = <String>{};
  Set<int> _visitedPlaceIds = <int>{};

  RegionPolygon? currentRegion;
  Set<Polygon> polygons = <Polygon>{};
  Set<Marker> markers = <Marker>{};

  final Map<String, List<PlaceOfInterest>> _placesCache =
      <String, List<PlaceOfInterest>>{};
  String? _activePlacesRegionId;

  LatLngBounds? _lastLoadedBounds;
  DateTime? _lastViewportLoadTime;
  bool _hasResolvedInitialCenter = false;

  void Function(PlaceOfInterest place)? onPlaceSelected;

  Future<void> initialise({String? userId}) async {
    _userId = userId;
    _hasResolvedInitialCenter = false;

    await _loadMapStyle();
    await PlaceOfInterest.preloadIcons();
    await _loadVisitedPolygonIds();

    if (_userId != null) {
      await _loadVisitedPlaces();
    }

    await _loadInitialRegion();
    await _startLocationUpdates();
  }

  Future<void> setUserId(String? userId) async {
    _userId = userId;

    if (userId == null) {
      _visitedPlaceIds = <int>{};
      visitedPolygonIds = <String>{};
      _refreshCachedPolygonStyles();
      _rebuildMarkers();
      notifyListeners();
      return;
    }

    await _loadVisitedPolygonIds();
    await _loadVisitedPlaces();

    if (currentRegion != null) {
      await _markRegionVisited(currentRegion!.id);
    }

    _rebuildMarkers();
    notifyListeners();
  }

  Future<void> disposeController() async {
    await _locationSubscription?.cancel();
    _googleMapController?.dispose();
  }

  Future<void> onMapCreated(GoogleMapController controller) async {
    _googleMapController = controller;

    await _googleMapController?.animateCamera(
      CameraUpdate.newLatLngZoom(center, defaultZoom),
    );

    if (_hasResolvedInitialCenter) {
      await _loadViewportRegions(force: true);
    }
  }

  void onCameraMove(CameraPosition position) {
    final sizeChanged = PlaceOfInterest.updateSizeForZoom(position.zoom);
    if (!sizeChanged) {
      return;
    }

    _rebuildMarkers();
    notifyListeners();
  }

  Future<void> _loadMapStyle() async {
    try {
      mapStyle = await rootBundle.loadString(_visitedTilesStyleAsset);
    } catch (error) {
      message = 'Failed to load map style';
      debugPrint('[MapController] Failed to load map style: $error');
      notifyListeners();
    }
  }

  Future<void> _loadVisitedPolygonIds() async {
    try {
      visitedPolygonIds = await _visitedRegionService.loadVisitedRegionIds();
      _refreshCachedPolygonStyles();
    } catch (error) {
      visitedPolygonIds = <String>{};
      message = 'Failed to load visited polygons';
      debugPrint('[MapController] Failed to load visited polygons: $error');
      notifyListeners();
    }
  }

  Future<void> _loadVisitedPlaces() async {
    if (_userId == null) {
      return;
    }

    try {
      _visitedPlaceIds = await _visitService.getVisitedPlaceIds(_userId!);
      debugPrint(
        '[MapController] Loaded ${_visitedPlaceIds.length} visited places',
      );
    } catch (error) {
      debugPrint('[MapController] Error loading visited places: $error');
    }
  }

  Future<void> _loadInitialRegion() async {
    try {
      final position = await _geoLocatorService.getCurrentLocation();
      final userCenter = LatLng(position.latitude, position.longitude);

      center = userCenter;
      myLocationEnabled = true;
      isLoading = false;

      notifyListeners();

      await _googleMapController?.animateCamera(
        CameraUpdate.newLatLngZoom(userCenter, defaultZoom),
      );

      await _loadCurrentRegionForPosition(position);
      _hasResolvedInitialCenter = true;
      await _loadViewportRegions(force: true);
    } catch (error) {
      center = fallbackCenter;
      isLoading = false;
      myLocationEnabled = false;
      message = 'Could not load your location: $error';
      _hasResolvedInitialCenter = true;

      notifyListeners();
      await _loadViewportRegions(force: true);
    }
  }

  Future<void> _loadCurrentRegionForPosition(Position position) async {
    try {
      final region = await _regionService.getContainingRegion(
        lat: position.latitude,
        lng: position.longitude,
      );

      final previousRegionId = currentRegion?.id;
      final nextRegionId = region?.id;
      final regionChanged = previousRegionId != nextRegionId;

      currentRegion = region;

      if (region == null) {
        _activePlacesRegionId = null;
        markers = <Marker>{};
        isLoadingPlaces = false;
        message = 'Location found, but no SA2 region was found';
        _refreshCachedPolygonStyles();
        notifyListeners();
        return;
      }

      _polygonCacheManager.cacheRegion(
        region: region,
        isVisited: _isRegionVisited(region.id),
        isCurrentRegion: true,
        onRegionTapped: onRegionTapped,
      );

      if (regionChanged) {
        _activePlacesRegionId = region.id;
        markers = <Marker>{};
        isLoadingPlaces = !_placesCache.containsKey(region.id);
        await _markRegionVisited(region.id);
        await _loadPlacesForRegion(region.id);
      } else {
        _rebuildMarkers();
      }

      message = region.name;
      _refreshCachedPolygonStyles();
      notifyListeners();
    } catch (error) {
      message = 'Location found, but region data could not be loaded: $error';
      notifyListeners();
    }
  }

  Future<void> _startLocationUpdates() async {
    await _locationSubscription?.cancel();

    try {
      final positionStream = await _geoLocatorService.getLocationUpdates();
      _locationSubscription = positionStream.listen(
        (position) {
          _refreshCurrentLocation(position);
        },
        onError: (Object error) {
          message = 'Location stream failed: $error';
          notifyListeners();
        },
      );
    } catch (error) {
      message = 'Could not start location updates: $error';
      notifyListeners();
    }
  }

  Future<void> _refreshCurrentLocation(Position position) async {
    try {
      center = LatLng(position.latitude, position.longitude);
      myLocationEnabled = true;

      await _loadCurrentRegionForPosition(position);
    } catch (error) {
      message = 'Location refresh failed: $error';
      notifyListeners();
    }
  }

  Future<void> loadViewportRegions() async {
    await _loadViewportRegions();
  }

  Future<void> _loadViewportRegions({bool force = false}) async {
    final controller = _googleMapController;

    if (controller == null) return;
    if (isLoadingViewport) return;
    if (!_hasResolvedInitialCenter && !force) return;
    if (!force && _isWithinDebounceWindow()) return;

    try {
      final bounds = await controller.getVisibleRegion();

      if (!force && _isSimilarToLastBounds(bounds)) {
        return;
      }

      isLoadingViewport = true;
      notifyListeners();

      final regions = await _regionService.getRegionsForViewport(
        south: bounds.southwest.latitude,
        west: bounds.southwest.longitude,
        north: bounds.northeast.latitude,
        east: bounds.northeast.longitude,
      );

      var newRegionCount = 0;

      for (final region in regions) {
        final wasAdded = _polygonCacheManager.cacheRegion(
          region: region,
          isVisited: _isRegionVisited(region.id),
          isCurrentRegion: _isCurrentRegion(region.id),
          onRegionTapped: onRegionTapped,
        );

        if (wasAdded) {
          newRegionCount++;
        }
      }

      polygons = _polygonCacheManager.polygons;
      _lastLoadedBounds = bounds;
      isLoadingViewport = false;

      if (newRegionCount > 0) {
        message = 'Loaded $newRegionCount new nearby regions';
      } else {
        message = 'Already loaded this area';
      }

      notifyListeners();
    } catch (error) {
      isLoadingViewport = false;
      message = 'Could not load nearby regions: $error';

      notifyListeners();
    }
  }

  bool _isRegionVisited(String regionId) {
    return visitedPolygonIds.contains(regionId);
  }

  bool _isCurrentRegion(String regionId) {
    return currentRegion?.id == regionId;
  }

  Future<void> _markRegionVisited(String regionId) async {
    if (visitedPolygonIds.contains(regionId)) {
      return;
    }

    final previousVisitedIds = visitedPolygonIds;

    if (_userId != null) {
      visitedPolygonIds = <String>{...visitedPolygonIds, regionId};
      _refreshCachedPolygonStyles();
    }

    final wasMarked = await _visitedRegionService.markVisited(
      regionId,
      visitedAt: DateTime.now(),
    );

    if (wasMarked) {
      visitedPolygonIds = <String>{...visitedPolygonIds, regionId};
      _refreshCachedPolygonStyles();
      return;
    }

    if (_userId != null) {
      visitedPolygonIds = previousVisitedIds;
      _refreshCachedPolygonStyles();
    }
  }

  void _refreshCachedPolygonStyles() {
    _polygonCacheManager.refreshStyles(
      shouldRenderAsVisited: _isRegionVisited,
      isCurrentRegion: _isCurrentRegion,
      onRegionTapped: onRegionTapped,
    );
    polygons = _polygonCacheManager.polygons;
  }

  bool _isWithinDebounceWindow() {
    final now = DateTime.now();

    if (_lastViewportLoadTime == null) {
      _lastViewportLoadTime = now;
      return false;
    }

    final difference = now.difference(_lastViewportLoadTime!);

    if (difference.inMilliseconds < 700) {
      return true;
    }

    _lastViewportLoadTime = now;
    return false;
  }

  bool _isSimilarToLastBounds(LatLngBounds newBounds) {
    final oldBounds = _lastLoadedBounds;

    if (oldBounds == null) return false;

    const threshold = 0.01;

    final southDiff =
        (newBounds.southwest.latitude - oldBounds.southwest.latitude).abs();
    final westDiff =
        (newBounds.southwest.longitude - oldBounds.southwest.longitude).abs();
    final northDiff =
        (newBounds.northeast.latitude - oldBounds.northeast.latitude).abs();
    final eastDiff =
        (newBounds.northeast.longitude - oldBounds.northeast.longitude).abs();

    return southDiff < threshold &&
        westDiff < threshold &&
        northDiff < threshold &&
        eastDiff < threshold;
  }

  void onRegionTapped(String regionId, String regionName) {
    message = regionName;
    notifyListeners();
  }

  Future<void> _loadPlacesForRegion(String regionId) async {
    if (_placesCache.containsKey(regionId)) {
      if (_activePlacesRegionId == regionId) {
        isLoadingPlaces = false;
      }
      _rebuildMarkers();
      return;
    }

    isLoadingPlaces = true;
    notifyListeners();

    try {
      final places = await _placesService.getPlacesForRegion(
        regionId: regionId,
      );
      _placesCache[regionId] = places;

      if (_activePlacesRegionId == regionId) {
        _rebuildMarkers();
        message = 'Loaded ${places.length} places in this region';
      }
    } catch (error) {
      if (_activePlacesRegionId == regionId) {
        message = 'Could not load places: $error';
      }
      debugPrint('[MapController] Error loading places: $error');
    } finally {
      if (_activePlacesRegionId == regionId) {
        isLoadingPlaces = false;
        notifyListeners();
      }
    }
  }

  void _rebuildMarkers() {
    final activeRegionId = _activePlacesRegionId;
    if (activeRegionId == null) {
      markers = <Marker>{};
      return;
    }

    final places = _placesCache[activeRegionId];
    if (places == null) {
      markers = <Marker>{};
      return;
    }

    markers = places
        .map(
          (place) => place.toMarker(
            onTap: onPlaceTapped,
            visited: _visitedPlaceIds.contains(place.id),
          ),
        )
        .toSet();
  }

  void onPlaceTapped(PlaceOfInterest place) {
    message = '${place.name} • ${place.category.displayName}';
    notifyListeners();
    onPlaceSelected?.call(place);
  }

  bool isPlaceVisited(int placeId) {
    return _visitedPlaceIds.contains(placeId);
  }

  Set<int> get visitedPlaceIds => Set.unmodifiable(_visitedPlaceIds);

  Future<double?> getDistanceToPlace(PlaceOfInterest place) async {
    try {
      final position = await _geoLocatorService.getCurrentLocation();
      return Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        place.location.latitude,
        place.location.longitude,
      );
    } catch (error) {
      debugPrint('[MapController] Error getting distance to place: $error');
      return null;
    }
  }

  Future<({bool isNear, double? distance})> checkProximity(
    PlaceOfInterest place,
  ) async {
    final distance = await getDistanceToPlace(place);
    if (distance == null) {
      return (isNear: false, distance: null);
    }

    return (isNear: distance <= visitProximityThreshold, distance: distance);
  }

  Future<VisitResult> markPlaceAsVisited(PlaceOfInterest place) async {
    if (_userId == null) {
      message = 'Please log in to mark places as visited';
      notifyListeners();
      return VisitResult.notLoggedIn;
    }

    if (_visitedPlaceIds.contains(place.id)) {
      message = 'You have already visited ${place.name}';
      notifyListeners();
      return VisitResult.alreadyVisited;
    }

    final proximity = await checkProximity(place);
    if (!proximity.isNear) {
      final distanceText = proximity.distance != null
          ? '${proximity.distance!.round()}m away'
          : 'too far away';
      message =
          'You need to be within ${visitProximityThreshold.round()}m to visit this place ($distanceText)';
      notifyListeners();
      return VisitResult.tooFar;
    }

    try {
      await _visitService.markVisited(userId: _userId!, place: place);
      _visitedPlaceIds.add(place.id);
      _rebuildMarkers();

      message = 'Visited ${place.name}!';
      notifyListeners();
      return VisitResult.success;
    } catch (error) {
      message = 'Could not save visit: $error';
      notifyListeners();
      return VisitResult.error;
    }
  }

  PlaceOfInterest? getPlaceById(int placeId) {
    for (final places in _placesCache.values) {
      for (final place in places) {
        if (place.id == placeId) {
          return place;
        }
      }
    }

    return null;
  }
}
