import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'place_of_interest.dart';
import 'places_service.dart';
import 'region_polygon.dart';
import 'region_polygon_cache.dart';
import 'region_service.dart';
import 'visit_service.dart';
import 'visited_region_service.dart';
import 'geolocator_service.dart';

/// Result of attempting to mark a place as visited.
enum VisitResult {
  /// Successfully marked as visited.
  success,

  /// User is not logged in.
  notLoggedIn,

  /// Place has already been visited.
  alreadyVisited,

  /// User is too far from the place (beyond proximity threshold).
  tooFar,

  /// An error occurred (network, Firestore, etc).
  error,
}

class MapController extends ChangeNotifier {
  static const LatLng fallbackCenter = LatLng(-37.8136, 144.9631);

  static const double defaultZoom = 13.5;

  /// Maximum distance (in meters) user can be from a place to mark it as visited.
  static const double visitProximityThreshold = 100.0;

  static const String _mapStyle = '''
[
  {
    "featureType": "poi",
    "elementType": "all",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "road",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "administrative.locality",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "administrative.neighborhood",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "transit",
    "elementType": "all",
    "stylers": [{"visibility": "off"}]
  }
]
''';

  final GeoLocatorService _geoLocatorService;
  final RegionService _regionService;
  final PlacesService _placesService;
  final VisitService _visitService;
  final VisitedRegionService _visitedRegionService;
  final RegionPolygonCache _regionPolygonCache;

  MapController({
    GeoLocatorService? geoLocatorService,
    RegionService? regionService,
    PlacesService? placesService,
    VisitService? visitService,
    VisitedRegionService? visitedRegionService,
    RegionPolygonCache? regionPolygonCache,
  }) : _geoLocatorService = geoLocatorService ?? GeoLocatorService(),
       _regionService = regionService ?? RegionService(),
       _placesService = placesService ?? PlacesService(),
       _visitService = visitService ?? VisitService(),
       _visitedRegionService = visitedRegionService ?? VisitedRegionService(),
       _regionPolygonCache = regionPolygonCache ?? RegionPolygonCache();

  GoogleMapController? _googleMapController;
  StreamSubscription<Position>? _locationUpdatesSubscription;

  LatLng center = fallbackCenter;
  bool myLocationEnabled = false;
  bool isLoading = true;
  bool isLoadingViewport = false;
  bool isLoadingPlaces = false;
  String? message;

  // User authentication
  String? _userId;

  // Visited places tracking
  Set<int> _visitedPlaceIds = {};
  Set<String> _visitedRegionIds = <String>{};

  RegionPolygon? currentRegion;
  Set<Polygon> polygons = {};
  Set<Marker> markers = {};

  /// Exposes the map style for use by MapRender.
  String get mapStyle => _mapStyle;

  // cache places to avoid re-fetching (key = regionId)
  final Map<String, List<PlaceOfInterest>> _placesCache = {};

  LatLngBounds? _lastLoadedBounds;
  DateTime? _lastViewportLoadTime;
  bool _isResolvingCurrentRegion = false;
  Position? _queuedRegionCheckPosition;

  Future<void> initialise({String? userId}) async {
    _userId = userId;

    // Pre-load circle icons for all place categories
    await PlaceOfInterest.preloadIcons();

    // Load persisted visit state before any polygons are rendered.
    if (_userId != null) {
      await _loadVisitedPlaces();
      await _loadVisitedRegionIds();
    } else {
      _visitedRegionIds = <String>{};
    }

    _refreshCachedPolygonsStyles();
    await _loadInitialRegion();
  }

  /// Sets the user ID and loads their visited places.
  /// Call this when the user logs in.
  Future<void> setUserId(String? userId) async {
    _userId = userId;
    if (userId != null) {
      await _loadVisitedPlaces();
      await _loadVisitedRegionIds();
    } else {
      _visitedPlaceIds = {};
      _visitedRegionIds = <String>{};
    }
    _rebuildMarkers();
    _refreshCachedPolygonsStyles();
    notifyListeners();
  }

  /// Load visited place IDs from Firestore.
  Future<void> _loadVisitedPlaces() async {
    if (_userId == null) return;

    try {
      _visitedPlaceIds = await _visitService.getVisitedPlaceIds(_userId!);
      debugPrint(
        '[MapController] Loaded ${_visitedPlaceIds.length} visited places',
      );
    } catch (error) {
      debugPrint('[MapController] Error loading visited places: $error');
    }
  }

  /// Load visited region IDs from Firestore.
  Future<void> _loadVisitedRegionIds() async {
    if (_userId == null) return;

    try {
      _visitedRegionIds = await _visitedRegionService.loadVisitedRegionIds();
      debugPrint(
        '[MapController] Loaded ${_visitedRegionIds.length} visited regions',
      );
    } catch (error) {
      debugPrint('[MapController] Error loading visited regions: $error');
    }
  }

  void disposeController() {
    unawaited(_locationUpdatesSubscription?.cancel());
    _locationUpdatesSubscription = null;
    _googleMapController?.dispose();
  }

  Future<void> onMapCreated(GoogleMapController controller) async {
    _googleMapController = controller;

    await _googleMapController?.animateCamera(
      CameraUpdate.newLatLngZoom(center, defaultZoom),
    );

    await loadViewportRegions();
  }

  /// Handle camera movement to update marker sizes based on zoom level.
  void onCameraMove(CameraPosition position) {
    final sizeChanged = PlaceOfInterest.updateSizeForZoom(position.zoom);
    if (sizeChanged) {
      // Rebuild markers with new size
      _rebuildMarkers();
      notifyListeners();
    }
  }

  // polygon for the region you are in

  Future<void> _loadInitialRegion() async {
    try {
      debugPrint('[MapController] Loading initial region...');

      final Position position = await _geoLocatorService.getCurrentLocation();

      debugPrint(
        '[MapController] User location: ${position.latitude}, ${position.longitude}',
      );

      final userCenter = LatLng(position.latitude, position.longitude);

      final region = await _regionService.getContainingRegion(
        lat: position.latitude,
        lng: position.longitude,
      );

      center = userCenter;
      currentRegion = region;
      myLocationEnabled = true;
      isLoading = false;

      if (region == null) {
        message = 'No SA2 region found';
      } else {
        message = region.name;
        _cacheRegionAsPolygons(region: region);
        await _markRegionAsVisited(region.id);
        _refreshCachedPolygonsStyles();

        // Load places for the current (unlocked) region
        await _loadPlacesForRegion(region.id);
      }

      polygons = _regionPolygonCache.polygons;

      notifyListeners();

      await _googleMapController?.animateCamera(
        CameraUpdate.newLatLngZoom(userCenter, defaultZoom),
      );

      await _startLocationUpdates();
    } catch (error) {
      center = fallbackCenter;
      isLoading = false;
      myLocationEnabled = false;
      message = 'Could not load location/region: $error';
      debugPrint('[MapController] Initial region/location error: $error');

      notifyListeners();
    }
  }

  Future<void> _startLocationUpdates() async {
    if (_locationUpdatesSubscription != null) {
      return;
    }

    try {
      final locationUpdates = await _geoLocatorService.getLocationUpdates();
      _locationUpdatesSubscription = locationUpdates.listen(
        _queueRegionCheck,
        onError: (Object error) {
          debugPrint('[MapController] Location updates error: $error');
        },
      );
    } catch (error) {
      debugPrint('[MapController] Could not start location updates: $error');
    }
  }

  void _queueRegionCheck(Position position) {
    _queuedRegionCheckPosition = position;

    if (_isResolvingCurrentRegion) {
      return;
    }

    unawaited(_drainQueuedRegionChecks());
  }

  Future<void> _drainQueuedRegionChecks() async {
    if (_isResolvingCurrentRegion) {
      return;
    }

    _isResolvingCurrentRegion = true;

    try {
      while (_queuedRegionCheckPosition != null) {
        final position = _queuedRegionCheckPosition!;
        _queuedRegionCheckPosition = null;
        await _syncCurrentRegionForPosition(position);
      }
    } finally {
      _isResolvingCurrentRegion = false;
    }
  }

  Future<void> _syncCurrentRegionForPosition(Position position) async {
    final previousRegionId = currentRegion?.id;

    try {
      final region = await _regionService.getContainingRegion(
        lat: position.latitude,
        lng: position.longitude,
      );

      final nextRegionId = region?.id;

      if (nextRegionId == previousRegionId) {
        return;
      }

      currentRegion = region;

      if (region == null) {
        message = 'No SA2 region found';
        _refreshCachedPolygonsStyles();
        notifyListeners();
        return;
      }

      debugPrint(
        '[MapController] Current region changed: $previousRegionId -> ${region.id}',
      );

      message = region.name;
      _cacheRegionAsPolygons(region: region);
      await _markRegionAsVisited(region.id);
      _refreshCachedPolygonsStyles();
      await _loadPlacesForRegion(region.id);
      notifyListeners();
    } catch (error) {
      debugPrint('[MapController] Error resolving current region: $error');
    }
  }

  // load all other polyons in view and cache

  Future<void> loadViewportRegions() async {
    final controller = _googleMapController;

    if (controller == null) return;
    if (isLoadingViewport) return;
    if (_isWithinDebounceWindow()) return;

    try {
      final bounds = await controller.getVisibleRegion();

      if (_isSimilarToLastBounds(bounds)) {
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
        final wasAdded = _cacheRegionAsPolygons(region: region);

        if (wasAdded) {
          newRegionCount++;
        }
      }

      polygons = _regionPolygonCache.polygons;
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

  bool _cacheRegionAsPolygons({required RegionPolygon region}) {
    final wasAdded = _regionPolygonCache.cacheRegion(
      region: region,
      isVisited: _visitedRegionIds.contains(region.id),
      isCurrentRegion: currentRegion?.id == region.id,
      onRegionTapped: onRegionTapped,
    );

    polygons = _regionPolygonCache.polygons;

    return wasAdded;
  }

  void _refreshCachedPolygonsStyles() {
    _regionPolygonCache.refreshStyles(
      shouldRenderAsVisited: (regionId) => _visitedRegionIds.contains(regionId),
      isCurrentRegion: (regionId) => currentRegion?.id == regionId,
      onRegionTapped: onRegionTapped,
    );

    polygons = _regionPolygonCache.polygons;
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

  // ─────────────────────────────────────────────────────────────────────────────
  // PLACES METHODS
  // ─────────────────────────────────────────────────────────────────────────────

  /// Load places for a specific region.
  /// Only fetches from API if not already cached.
  Future<void> _loadPlacesForRegion(String regionId) async {
    debugPrint('[MapController] _loadPlacesForRegion called for: $regionId');

    // Already cached? Just rebuild markers
    if (_placesCache.containsKey(regionId)) {
      debugPrint(
        '[MapController] Cache hit - ${_placesCache[regionId]!.length} places',
      );
      _rebuildMarkers();
      return;
    }

    isLoadingPlaces = true;
    notifyListeners();

    try {
      debugPrint('[MapController] Fetching places from API...');
      final places = await _placesService.getPlacesForRegion(
        regionId: regionId,
      );

      debugPrint('[MapController] API returned ${places.length} places');
      _placesCache[regionId] = places;
      _rebuildMarkers();
      debugPrint('[MapController] Markers rebuilt: ${markers.length}');

      message = 'Loaded ${places.length} places in this region';
    } catch (error) {
      debugPrint('[MapController] ERROR loading places: $error');
      message = 'Could not load places: $error';
    } finally {
      isLoadingPlaces = false;
      notifyListeners();
    }
  }

  /// Rebuild the markers set from all cached places.
  void _rebuildMarkers() {
    final allMarkers = <Marker>{};

    for (final places in _placesCache.values) {
      for (final place in places) {
        final isVisited = _visitedPlaceIds.contains(place.id);
        allMarkers.add(
          place.toMarker(onTap: onPlaceTapped, visited: isVisited),
        );
      }
    }

    markers = allMarkers;
  }

  /// Callback invoked when a place marker is tapped.
  /// Set this to show the place details sheet.
  void Function(PlaceOfInterest place)? onPlaceSelected;

  /// Called when a place marker is tapped.
  void onPlaceTapped(PlaceOfInterest place) {
    message = '${place.name} • ${place.category.displayName}';
    notifyListeners();

    // Notify external listener (e.g., to show details sheet)
    onPlaceSelected?.call(place);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // VISIT METHODS
  // ─────────────────────────────────────────────────────────────────────────────

  /// Check if a place has been visited by the current user.
  bool isPlaceVisited(int placeId) {
    return _visitedPlaceIds.contains(placeId);
  }

  /// Get all visited place IDs.
  Set<int> get visitedPlaceIds => Set.unmodifiable(_visitedPlaceIds);

  /// Get all visited region IDs.
  Set<String> get visitedRegionIds => Set.unmodifiable(_visitedRegionIds);

  /// Calculate distance in meters between user's current location and a place.
  /// Returns null if unable to get user location.
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

  /// Check if user is within proximity threshold of a place.
  /// Returns the distance in meters, or null if unable to determine.
  Future<({bool isNear, double? distance})> checkProximity(
    PlaceOfInterest place,
  ) async {
    final distance = await getDistanceToPlace(place);
    if (distance == null) {
      return (isNear: false, distance: null);
    }
    return (isNear: distance <= visitProximityThreshold, distance: distance);
  }

  /// Mark a place as visited.
  /// Validates that user is within [visitProximityThreshold] meters of the place.
  Future<VisitResult> markPlaceAsVisited(PlaceOfInterest place) async {
    if (_userId == null) {
      debugPrint('[MapController] Cannot mark visited: no user logged in');
      message = 'Please log in to mark places as visited';
      notifyListeners();
      return VisitResult.notLoggedIn;
    }

    if (_visitedPlaceIds.contains(place.id)) {
      debugPrint('[MapController] Place ${place.id} already visited');
      message = 'You have already visited ${place.name}';
      notifyListeners();
      return VisitResult.alreadyVisited;
    }

    // Check proximity
    final proximity = await checkProximity(place);
    if (!proximity.isNear) {
      final distanceText = proximity.distance != null
          ? '${proximity.distance!.round()}m away'
          : 'too far away';
      debugPrint('[MapController] User is $distanceText from ${place.name}');
      message =
          'You need to be within ${visitProximityThreshold.round()}m to visit this place ($distanceText)';
      notifyListeners();
      return VisitResult.tooFar;
    }

    try {
      await _visitService.markVisited(userId: _userId!, place: place);

      _visitedPlaceIds.add(place.id);
      final regionVisitChanged = await _markRegionAsVisited(place.regionId);
      if (regionVisitChanged) {
        _refreshCachedPolygonsStyles();
      }
      _rebuildMarkers();

      message = 'Visited ${place.name}!';
      notifyListeners();

      debugPrint('[MapController] Marked place ${place.id} as visited');
      return VisitResult.success;
    } catch (error) {
      debugPrint('[MapController] Error marking place as visited: $error');
      message = 'Could not save visit: $error';
      notifyListeners();
      return VisitResult.error;
    }
  }

  /// Get a place by its ID from the cache.
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

  Future<bool> _markRegionAsVisited(String regionId) async {
    if (_visitedRegionIds.contains(regionId)) {
      return false;
    }

    try {
      final didPersistVisit = await _visitedRegionService.markVisited(regionId);

      if (!didPersistVisit) {
        debugPrint(
          '[MapController] Region $regionId visit was not persisted because there is no authenticated user',
        );
        return false;
      }

      _visitedRegionIds.add(regionId);
      debugPrint('[MapController] Marked region $regionId as visited');
      return true;
    } catch (error) {
      debugPrint(
        '[MapController] Error marking region $regionId as visited: $error',
      );
      return false;
    }
  }
}
