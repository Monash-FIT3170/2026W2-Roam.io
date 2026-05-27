/*
 * Author: Sanjevan Rajasegar 
 * Last Modified: 24/05/2026
 * Description:
 *   Coordinates the map feature
 *
 *   Current MVP behaviour:
 *   - SA1 tiles render normally when zoomed in.
 *   - When zoomed out far, unvisited SA1 fog tiles are hidden.
 *   - Visited/current tiles remain visible as progress markers.
 *   - SA3 polygon rendering is intentionally disabled for now because swapping
 *     large Google Maps polygon sets causes UI freezes.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../profile/domain/xp_reward_config.dart';
import 'geolocator_service.dart';
import 'map_viewport_policy.dart';
import 'place_marker_manager.dart';
import 'place_of_interest.dart';
import 'region_polygon.dart';
import 'region_polygon_cache.dart';
import 'region_service.dart';
import 'tile_unlock_xp_service.dart';
import 'visit_service.dart';
import 'visited_region_service.dart';
import 'viewport_region_loader.dart';
import '../../../services/polygon_service.dart';

enum VisitResult { success, notLoggedIn, alreadyVisited, tooFar, error }

class MapController extends ChangeNotifier {
  static const LatLng fallbackCenter = LatLng(-37.8136, 144.9631);
  static const double defaultZoom = MapViewportPolicy.defaultZoom;
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

  MapController({
    GeoLocatorService? geoLocatorService,
    RegionService? regionService,
    VisitService? visitService,
    VisitedRegionService? visitedRegionService,
    RegionPolygonCache? regionPolygonCache,
    TileUnlockXpService? tileUnlockXpService,
    ViewportRegionLoader? viewportRegionLoader,
    PlaceMarkerManager? placeMarkerManager,
    MapViewportPolicy? viewportPolicy,
    PolygonService? polygonService,
  }) : _geoLocatorService = geoLocatorService ?? GeoLocatorService(),
       _regionService = regionService ?? RegionService(),
       _visitService = visitService ?? VisitService(),
       _visitedRegionService = visitedRegionService ?? VisitedRegionService(),
       _regionPolygonCache = regionPolygonCache ?? RegionPolygonCache(),
       _tileUnlockXpService = tileUnlockXpService ?? TileUnlockXpService(),
       _viewportRegionLoader = viewportRegionLoader ?? ViewportRegionLoader(),
       _placeMarkerManager = placeMarkerManager ?? PlaceMarkerManager(),
      _viewportPolicy = viewportPolicy ?? MapViewportPolicy(),
      _polygonService = polygonService ?? PolygonService();
       

  final GeoLocatorService _geoLocatorService;
  final RegionService _regionService;
  final VisitService _visitService;
  final VisitedRegionService _visitedRegionService;
  final RegionPolygonCache _regionPolygonCache;
  final TileUnlockXpService _tileUnlockXpService;
  final ViewportRegionLoader _viewportRegionLoader;
  final PlaceMarkerManager _placeMarkerManager;
  final MapViewportPolicy _viewportPolicy;
  final PolygonService _polygonService;

  GoogleMapController? _googleMapController;
  StreamSubscription<Position>? _locationUpdatesSubscription;

  String? _userId;
  Future<void> Function(int amount)? _onVisitXpAwarded;

  Set<int> _visitedPlaceIds = {};
  Set<String> _visitedRegionIds = <String>{};
  Map<String, int> _visitCountsByRegion = <String, int>{};
  Map<String, int> _entryCountsByRegion = <String, int>{};

  bool _isHeatmapEnabled = false;
  bool _isResolvingCurrentRegion = false;
  Position? _queuedRegionCheckPosition;

  double _currentZoom = defaultZoom;
  MapLayerMode _currentLayerMode = MapLayerMode.sa1Detail;

  LatLng center = fallbackCenter;
  bool myLocationEnabled = false;
  bool isLoading = true;
  bool isLoadingViewport = false;
  bool isLoadingPlaces = false;
  String? message;

  RegionPolygon? currentRegion;
  Set<Polygon> polygons = {};
  Set<Marker> markers = {};

  void Function(PlaceOfInterest place)? onPlaceSelected;
  void Function(RegionPolygon region, int xpAwarded)? onRegionUnlockRewarded;
  void Function(RegionPolygon region, int xpAwarded)?
  onRegionUnlockCelebrationRewarded;

  String? get userId => _userId;
  String get mapStyle => _mapStyle;
  bool get isHeatmapEnabled => _isHeatmapEnabled;
  Set<int> get visitedPlaceIds => Set.unmodifiable(_visitedPlaceIds);
  Set<String> get visitedRegionIds => Set.unmodifiable(_visitedRegionIds);
  Map<String, int> get visitCountsByRegion =>
      Map<String, int>.unmodifiable(_visitCountsByRegion);

  void bindVisitXpAwarding(
    Future<void> Function(int amount)? onVisitXpAwarded,
  ) {
    _onVisitXpAwarded = onVisitXpAwarded;
  }

  Future<void> initialise({
    String? userId,
    Future<void> Function(int amount)? onVisitXpAwarded,
  }) async {
    _userId = userId;
    _onVisitXpAwarded = onVisitXpAwarded;

    await PlaceOfInterest.preloadIcons();
    await _loadUserVisitState();

    _placeMarkerManager.setVisitedPlaceIds(_visitedPlaceIds);
    _refreshCachedPolygonsStyles();

    await _loadInitialRegion();
  }

  Future<void> setUserId(String? userId) async {
    _userId = userId;

    await _loadUserVisitState();

    _placeMarkerManager.setVisitedPlaceIds(_visitedPlaceIds);
    _placeMarkerManager.rebuildMarkers(onPlaceTapped: onPlaceTapped);
    markers = _placeMarkerManager.markers;

    _refreshCachedPolygonsStyles();
    notifyListeners();
  }

  Future<void> refreshVisitedPlaces() async {
    await _loadVisitedPlaces();

    _placeMarkerManager.setVisitedPlaceIds(_visitedPlaceIds);
    _placeMarkerManager.rebuildMarkers(onPlaceTapped: onPlaceTapped);
    markers = _placeMarkerManager.markers;

    notifyListeners();
  }

  Future<void> toggleHeatmap() async {
    _isHeatmapEnabled = !_isHeatmapEnabled;

    if (_isHeatmapEnabled && _userId != null) {
      await _loadEntryCountsByRegion();
      await loadViewportRegions(force: true);
    }

    _refreshCachedPolygonsStyles();
    notifyListeners();
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

    // Initial viewport loading happens after the real user location is resolved.
  }

  void onCameraMove(CameraPosition position) {
    _currentZoom = position.zoom;

    final markerSizeChanged = _placeMarkerManager.updateMarkerSizeForZoom(
      position.zoom,
    );

    if (markerSizeChanged) {
      _placeMarkerManager.rebuildMarkers(onPlaceTapped: onPlaceTapped);
      markers = _placeMarkerManager.markers;
      notifyListeners();
    }
  }

  Future<void> loadViewportRegions({bool force = false}) async {
    final controller = _googleMapController;
    if (controller == null) return;

    final targetMode = _viewportPolicy.modeForZoom(
      zoom: _currentZoom,
      currentMode: _currentLayerMode,
    );

    if (targetMode == MapLayerMode.sa3Overview) {
      _currentLayerMode = MapLayerMode.sa3Overview;
      _syncPolygonsForCurrentMode();
      notifyListeners();
      return;
    }

    if (_currentLayerMode != MapLayerMode.sa1Detail) {
      _currentLayerMode = MapLayerMode.sa1Detail;
      _syncPolygonsForCurrentMode();
      notifyListeners();
    }

    isLoadingViewport = true;
    notifyListeners();

    try {
      final result = await _viewportRegionLoader.load(
        mapController: controller,
        currentZoom: _currentZoom,
        currentMode: _currentLayerMode,
        force: force,
      );

      if (result.message != null) {
        message = result.message;
      }

      if (!result.didSkip) {
        var newRegionCount = 0;

        for (final region in result.regions) {
          final cacheResult = _cacheRegionAsPolygons(region);

          if (cacheResult.wasAdded) {
            newRegionCount++;
          }
        }

        message = 'Loaded $newRegionCount new nearby tiles';
      }

      _syncPolygonsForCurrentMode();
    } catch (error) {
      message = 'Could not load nearby regions: $error';
      debugPrint('[MapController] Viewport loading error: $error');
    } finally {
      isLoadingViewport = false;
      notifyListeners();
    }
  }

  void onRegionTapped(String regionId, String regionName) {
    message = regionName;
    notifyListeners();
  }

  void onPlaceTapped(PlaceOfInterest place) {
    message = '${place.name} • ${place.category.displayName}';
    notifyListeners();

    onPlaceSelected?.call(place);
  }

  bool isPlaceVisited(int placeId) {
    return _visitedPlaceIds.contains(placeId);
  }

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

  Future<VisitResult> markPlaceAsVisited(
    PlaceOfInterest place, {
    String? customName,
    String? description,
    List<String>? mediaUrls,
  }) async {
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
      await _visitService.markVisited(
        userId: _userId!,
        place: place,
        customName: customName,
        description: description,
        mediaUrls: mediaUrls,
      );
    } catch (error) {
      message = 'Could not save visit: $error';
      notifyListeners();
      return VisitResult.error;
    }

    await _awardVisitXpSafely();

    _visitedPlaceIds.add(place.id);
    _visitCountsByRegion.update(
      place.regionId,
      (count) => count + 1,
      ifAbsent: () => 1,
    );

    _placeMarkerManager.setVisitedPlaceIds(_visitedPlaceIds);
    _placeMarkerManager.rebuildMarkers(onPlaceTapped: onPlaceTapped);
    markers = _placeMarkerManager.markers;

    _refreshCachedPolygonsStyles();

    message = 'Visited ${place.name}!';
    notifyListeners();

    return VisitResult.success;
  }

  PlaceOfInterest? getPlaceById(int placeId) {
    return _placeMarkerManager.getPlaceById(placeId);
  }

  Future<void> _loadInitialRegion() async {
    try {
      debugPrint('[MapController] Loading initial region...');

      final position = await _geoLocatorService.getCurrentLocation();
      final userCenter = LatLng(position.latitude, position.longitude);

      center = userCenter;
      myLocationEnabled = true;
      isLoading = false;

      final region = await _regionService.getContainingRegion(
        lat: position.latitude,
        lng: position.longitude,
      );

      if (region == null) {
        currentRegion = null;
        message = 'No SA1 region found';
      } else {
        await _handleCurrentRegion(region);
      }

      _syncPolygonsForCurrentMode();
      notifyListeners();

      await _googleMapController?.animateCamera(
        CameraUpdate.newLatLngZoom(userCenter, defaultZoom),
      );

      await Future.delayed(const Duration(milliseconds: 350));
      await loadViewportRegions(force: true);

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

  Future<void> _handleCurrentRegion(RegionPolygon region) async {
    currentRegion = region;

    final cacheResult = _cacheRegionAsPolygons(region);
    final effectiveRegion = cacheResult.region;

    currentRegion = effectiveRegion;
    message = effectiveRegion.name;

    await _markRegionAsVisited(effectiveRegion);
    // Record an entry for heatmap counts (app opened / entered tile).
    await _recordRegionEntry(effectiveRegion);
    _refreshCachedPolygonsStyles();

    await _loadPlacesForRegion(effectiveRegion.id);
  }

  Future<void> _loadPlacesForRegion(String regionId) async {
    isLoadingPlaces = true;
    notifyListeners();

    try {
      final places = await _placeMarkerManager.loadPlacesForRegion(
        regionId: regionId,
        onPlaceTapped: onPlaceTapped,
      );

      markers = _placeMarkerManager.markers;
      message = 'Loaded ${places.length} places in this region';
    } catch (error) {
      message = 'Could not load places: $error';
      debugPrint('[MapController] Places loading error: $error');
    } finally {
      isLoadingPlaces = false;
      notifyListeners();
    }
  }

  Future<void> _startLocationUpdates() async {
    if (_locationUpdatesSubscription != null) return;

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

    if (_isResolvingCurrentRegion) return;

    unawaited(_drainQueuedRegionChecks());
  }

  Future<void> _drainQueuedRegionChecks() async {
    if (_isResolvingCurrentRegion) return;

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

      if (region?.id == previousRegionId) return;

      if (region == null) {
        currentRegion = null;
        message = 'No SA1 region found';
        _refreshCachedPolygonsStyles();
        notifyListeners();
        return;
      }

      debugPrint(
        '[MapController] Current region changed: $previousRegionId -> ${region.id}',
      );

      await _handleCurrentRegion(region);
      notifyListeners();
    } catch (error) {
      debugPrint('[MapController] Error resolving current region: $error');
    }
  }

  RegionPolygonCacheResult _cacheRegionAsPolygons(RegionPolygon region) {
    final cacheResult = _regionPolygonCache.cacheRegion(
      region: region,
      isVisited: _visitedRegionIds.contains(region.id),
      isCurrentRegion: currentRegion?.id == region.id,
      onRegionTapped: onRegionTapped,
      heatmapIntensity: _heatmapIntensityForRegion(region.id),
    );

    _syncPolygonsForCurrentMode();

    return cacheResult;
  }

  void _refreshCachedPolygonsStyles() {
    _regionPolygonCache.refreshStyles(
      shouldRenderAsVisited: (regionId) => _visitedRegionIds.contains(regionId),
      isCurrentRegion: (regionId) => currentRegion?.id == regionId,
      onRegionTapped: onRegionTapped,
      heatmapIntensityForRegion: _heatmapIntensityForRegion,
    );

    _syncPolygonsForCurrentMode();
  }

  void _syncPolygonsForCurrentMode() {
    if (_currentLayerMode == MapLayerMode.sa1Detail) {
      polygons = _regionPolygonCache.polygonsForDisplay(
        showUnvisitedRegions: true,
        visitedRegionIds: _visitedRegionIds,
        currentRegionId: currentRegion?.id,
      );
      return;
    }

    polygons = _regionPolygonCache.polygonsForDisplay(
      showUnvisitedRegions: false,
      visitedRegionIds: _visitedRegionIds,
      currentRegionId: currentRegion?.id,
    );
  }

  Future<void> _loadUserVisitState() async {
    if (_userId == null) {
      _visitedPlaceIds = {};
      _visitedRegionIds = <String>{};
      _visitCountsByRegion = <String, int>{};
      return;
    }

    await _loadVisitedPlaces();
    await _loadVisitedRegionIds();
    // Load entry counts when heatmap is enabled, otherwise fall back to
    // historical place-visit counts used elsewhere in the UI.
    if (_isHeatmapEnabled) {
      await _loadEntryCountsByRegion();
    } else {
      await _loadVisitCountsByRegion();
    }
  }

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

  Future<void> _loadVisitCountsByRegion() async {
    if (_userId == null) return;

    try {
      _visitCountsByRegion = await _visitService.getVisitCountsByRegion(
        _userId!,
        validRegionIds: _visitedRegionIds,
      );

      debugPrint(
        '[MapController] Loaded visit counts for ${_visitCountsByRegion.length} SA1 regions',
      );
    } catch (error) {
      debugPrint(
        '[MapController] Error loading visit counts by region: $error',
      );
    }
  }

  Future<void> _loadEntryCountsByRegion() async {
    if (_userId == null) return;

    try {
      _entryCountsByRegion = await _polygonService.getPolygonEntryCounts(
        profileId: _userId!,
        validPolygonIds: _visitedRegionIds.isEmpty ? null : _visitedRegionIds,
      );

      debugPrint(
        '[MapController] Loaded entry counts for ${_entryCountsByRegion.length} SA1 regions',
      );
    } catch (error) {
      debugPrint('[MapController] Error loading entry counts by region: $error');
    }
  }

  Future<void> _recordRegionEntry(RegionPolygon region) async {
    if (_userId == null) return;

    try {
      // Optimistically update local cache so the heatmap updates immediately.
      _entryCountsByRegion.update(region.id, (c) => c + 1, ifAbsent: () => 1);

      unawaited(_polygonService.incrementPolygonEntryCount(
        profileId: _userId!,
        polygonId: region.id,
      ));
    } catch (error) {
      debugPrint('[MapController] Error recording region entry: $error');
    }
  }

  Future<bool> _markRegionAsVisited(RegionPolygon region) async {
    final regionId = region.id;

    if (_visitedRegionIds.contains(regionId)) {
      return false;
    }

    try {
      final didPersistVisit = await _visitedRegionService.markVisited(regionId);

      if (!didPersistVisit) {
        return false;
      }

      _visitedRegionIds.add(regionId);

      final xpResult = await _awardUnlockXp(region);

      if (xpResult != null) {
        if (xpResult.didLevelUp) {
          onRegionUnlockCelebrationRewarded?.call(region, xpResult.xpAwarded);
        } else {
          onRegionUnlockRewarded?.call(region, xpResult.xpAwarded);
        }
      }

      return true;
    } catch (error) {
      debugPrint(
        '[MapController] Error marking region $regionId as visited: $error',
      );
      return false;
    }
  }

  Future<TileUnlockXpResult?> _awardUnlockXp(RegionPolygon region) async {
    try {
      return await _tileUnlockXpService.awardForUnlockedPolygon(region);
    } catch (error) {
      debugPrint(
        '[MapController] Error awarding XP for region ${region.id}: $error',
      );
      return null;
    }
  }

  Future<void> _awardVisitXpSafely() async {
    try {
      await _onVisitXpAwarded?.call(XpRewardConfig.visitXpReward);
    } catch (error) {
      debugPrint('[MapController] Visit XP award failed after save: $error');
    }
  }

  double? _heatmapIntensityForRegion(String regionId) {
    if (!_isHeatmapEnabled || !_visitedRegionIds.contains(regionId)) {
      return null;
    }

    final regionCount = _entryCountsByRegion[regionId] ?? 0;

    debugPrint(
      '[Heatmap] region=$regionId '
      'enabled=$_isHeatmapEnabled '
      'visited=${_visitedRegionIds.contains(regionId)} '
      'count=$regionCount',
    );

    return _heatmapIntensityForCount(regionCount);
  }

  double _heatmapIntensityForCount(int regionCount) {
    if (regionCount <= 0) {
      return 0.0;
    }

    if (regionCount <= 2) {
      return 0.2;
    }

    if (regionCount <= 4) {
      return 0.6;
    }

    return 1.0;
  }

  int get _maxVisitCountAcrossVisitedRegions {
    var maxCount = 0;

    for (final regionId in _visitedRegionIds) {
      final regionCount = _entryCountsByRegion[regionId] ?? 0;

      if (regionCount > maxCount) {
        maxCount = regionCount;
      }
    }

    return maxCount;
  }

  int get _maxEntryCountAcrossVisitedRegions => _maxVisitCountAcrossVisitedRegions;
}
