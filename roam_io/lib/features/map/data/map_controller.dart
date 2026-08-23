/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Owns the map feature's state and business logic. This controller resolves
 *   the user's current region, loads viewport polygons and places, caches map
 *   data for redraws, persists visits, awards visit and region unlock XP, and
 *   exposes heatmap styling state for visited tiles. Unlock XP toasts only fire
 *   when the canonical XP award succeeds.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/exploration_mode.dart';
import '../fog/fog_controller.dart';
import '../fog/fog_decay_difficulty.dart';
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
import '../../you/services/exploration_stats_service.dart';
import '../../../services/polygon_service.dart';

enum VisitResult { success, notLoggedIn, alreadyVisited, tooFar, error }

class MapController extends ChangeNotifier {
  static const LatLng fallbackCenter = LatLng(-37.8136, 144.9631);
  static const double defaultZoom = MapViewportPolicy.defaultZoom;
  static const double visitProximityThreshold = 100.0;

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
    ExplorationStatsService? explorationStatsService,
    FogDecayDifficulty fogDecayDifficulty = FogDecayDifficulty.quarterly,
  }) : _geoLocatorService = geoLocatorService ?? GeoLocatorService(),
       _regionService = regionService ?? RegionService(),
       _visitService = visitService ?? VisitService(),
       _visitedRegionService = visitedRegionService ?? VisitedRegionService(),
       _regionPolygonCache = regionPolygonCache ?? RegionPolygonCache(),
       _tileUnlockXpService = tileUnlockXpService ?? TileUnlockXpService(),
       _viewportRegionLoader = viewportRegionLoader ?? ViewportRegionLoader(),
       _placeMarkerManager = placeMarkerManager ?? PlaceMarkerManager(),
       _viewportPolicy = viewportPolicy ?? MapViewportPolicy(),
       _polygonService = polygonService,
       _explorationStatsService = explorationStatsService,
       _fogDecayDifficulty = fogDecayDifficulty;

  final GeoLocatorService _geoLocatorService;
  final RegionService _regionService;
  final VisitService _visitService;
  final VisitedRegionService _visitedRegionService;
  final RegionPolygonCache _regionPolygonCache;
  final TileUnlockXpService _tileUnlockXpService;
  final ViewportRegionLoader _viewportRegionLoader;
  final PlaceMarkerManager _placeMarkerManager;
  final MapViewportPolicy _viewportPolicy;
  PolygonService? _polygonService;
  ExplorationStatsService? _explorationStatsService;
  FogDecayDifficulty _fogDecayDifficulty;

  PolygonService get _resolvedPolygonService =>
      _polygonService ??= PolygonService();

  ExplorationStatsService get _resolvedExplorationStatsService =>
      _explorationStatsService ??= ExplorationStatsService(
        polygonService: _resolvedPolygonService,
      );

  GoogleMapController? _googleMapController;
  StreamSubscription<Position>? _locationUpdatesSubscription;
  Timer? _fogDecayRefreshTimer;

  /// Fog of war state, consumed by the FogOverlay stacked above the map.
  final FogController fogController = FogController();

  String? _userId;
  Future<void> Function(int amount)? _onVisitXpAwarded;

  Set<int> _visitedPlaceIds = {};
  Set<String> _visitedRegionIds = <String>{};
  Set<String> _fogClearedRegionIds = <String>{};
  Map<String, DateTime> _pendingFogReturnEvents = <String, DateTime>{};
  Map<String, int> _visitCountsByRegion = <String, int>{};
  Map<String, int> _entryCountsByRegion = <String, int>{};
  Set<String> _visibleViewportRegionIds = <String>{};

  bool _isHeatmapEnabled = false;
  bool _isResolvingCurrentRegion = false;
  Position? _queuedRegionCheckPosition;
  Position? _latestPosition;
  bool _isFollowingUser = true;
  bool _isProgrammaticCameraMove = false;

  ExplorationMode _currentMode = ExplorationMode.exploration;

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
  bool get isHeatmapEnabled => _isHeatmapEnabled;
  bool get isFollowingUser => _isFollowingUser;
  ExplorationMode get currentMode => _currentMode;
  Set<int> get visitedPlaceIds => Set.unmodifiable(_visitedPlaceIds);
  Set<String> get visitedRegionIds => Set.unmodifiable(_visitedRegionIds);
  Set<String> get fogClearedRegionIds => Set.unmodifiable(_fogClearedRegionIds);
  Map<String, int> get visitCountsByRegion =>
      Map<String, int>.unmodifiable(_visitCountsByRegion);

  Set<Polyline> exploredBoundaryPolylines(Color boundaryColor) {
    return _regionPolygonCache.exploredBoundaryPolylines(<String>{
      ..._visitedRegionIds,
      ?currentRegion?.id,
    }, boundaryColor: boundaryColor);
  }

  /// Sets the current exploration mode and notifies listeners.
  void setMode(ExplorationMode mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      notifyListeners();
    }
  }

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
    fogController.onFogReturnCompleted = _handleFogReturnCompleted;

    await PlaceOfInterest.preloadIcons();
    await _loadUserVisitState();
    _startFogDecayRefresh();

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
    _fogDecayRefreshTimer?.cancel();
    _fogDecayRefreshTimer = null;
    unawaited(_locationUpdatesSubscription?.cancel());
    _locationUpdatesSubscription = null;
    _googleMapController?.dispose();
    fogController.onFogReturnCompleted = null;
    fogController.dispose();
  }

  Future<void> onMapCreated(GoogleMapController controller) async {
    _googleMapController = controller;

    _isProgrammaticCameraMove = true;
    try {
      await _googleMapController?.animateCamera(
        CameraUpdate.newLatLngZoom(center, defaultZoom),
      );
    } catch (_) {
      _isProgrammaticCameraMove = false;
      rethrow;
    }

    // Initial viewport loading happens after the real user location is resolved.
  }

  void onCameraMove(CameraPosition position) {
    _currentZoom = position.zoom;

    // The fog overlay projects geometry itself, so it needs the camera every
    // frame. Deliberately not routed through notifyListeners: MapPage rebuilds
    // its whole subtree on notification, and this fires once per gesture frame.
    fogController.updateCamera(position, isMoving: true);

    final markerSizeChanged = _placeMarkerManager.updateMarkerSizeForZoom(
      position.zoom,
    );

    if (markerSizeChanged) {
      _placeMarkerManager.rebuildMarkers(onPlaceTapped: onPlaceTapped);
      markers = _placeMarkerManager.markers;
      notifyListeners();
    }
  }

  /// Stops automatic location following when the user moves the map.
  void onCameraMoveStarted() {
    fogController.setCameraMoving(true);

    if (!_isProgrammaticCameraMove) {
      _isFollowingUser = false;
    }
  }

  Future<void> onCameraIdle() async {
    _isProgrammaticCameraMove = false;
    fogController.setCameraMoving(false);
    await loadViewportRegions();
  }

  /// Re-centres the map and resumes following future location updates.
  Future<void> recenterOnUser() async {
    _isFollowingUser = true;
    final position =
        _latestPosition ?? await _geoLocatorService.getCurrentLocation();
    _latestPosition = position;
    await _moveCameraTo(position);
  }

  /// Keeps the map camera in sync with a location produced by journey
  /// tracking. A deliberate user camera movement still pauses following until
  /// [recenterOnUser] is used again.
  void followTrackedLocation(LatLng location) {
    center = location;
    if (_isFollowingUser) {
      unawaited(_moveCameraToLatLng(location));
    }
  }

  Future<void> _moveCameraTo(Position position) async {
    await _moveCameraToLatLng(LatLng(position.latitude, position.longitude));
  }

  Future<void> _moveCameraToLatLng(LatLng location) async {
    final controller = _googleMapController;
    if (controller == null) return;

    _isProgrammaticCameraMove = true;
    try {
      await controller.animateCamera(CameraUpdate.newLatLng(location));
    } catch (_) {
      _isProgrammaticCameraMove = false;
      rethrow;
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
      _visibleViewportRegionIds = <String>{};
      _placeMarkerManager.setVisibleRegionIds(const <String>{});
      markers = _placeMarkerManager.markers;
      _syncPolygonsForCurrentMode();
      notifyListeners();
      return;
    }

    if (_currentLayerMode != MapLayerMode.sa1Detail) {
      _currentLayerMode = MapLayerMode.sa1Detail;
      _syncPolygonsForCurrentMode();
      notifyListeners();
    }

    final clearedRegionIds = _clearedRegionIds();

    // Nothing explored means nothing the viewport fetch could usefully return,
    // since only cleared regions are rendered. Skip the request entirely rather
    // than downloading hundreds of polygons to throw all of them away, but
    // still mark the fog ready so a new account sees cloud instead of nothing.
    if (clearedRegionIds.isEmpty) {
      fogController.markViewportLoaded();
      return;
    }

    isLoadingViewport = true;
    notifyListeners();

    try {
      final result = await _viewportRegionLoader.load(
        mapController: controller,
        currentZoom: _currentZoom,
        currentMode: _currentLayerMode,
        clearedRegionIds: clearedRegionIds,
        force: force,
      );

      if (result.message != null) {
        message = result.message;
      }

      if (!result.didSkip) {
        var newRegionCount = 0;

        // Unvisited regions are dropped on arrival. The fog is drawn as the
        // screen minus cleared holes, so unexplored geometry is not an input to
        // it, and caching it would keep paying to parse, store and restyle
        // hundreds of polygons that are never rendered.
        final clearedRegions = result.regions
            .where((region) => _isRegionCleared(region.id))
            .toList();

        for (final region in clearedRegions) {
          final cacheResult = _cacheRegionAsPolygons(region);

          if (cacheResult.wasAdded) {
            newRegionCount++;
          }
        }

        fogController.addClearedRegions(clearedRegions);
        _startPendingFogReturnAnimation();
        message = 'Loaded $newRegionCount new nearby tiles';
      }

      fogController.markViewportLoaded();

      _syncPolygonsForCurrentMode();
      final visibleBounds = await controller.getVisibleRegion();
      _visibleViewportRegionIds = _regionPolygonCache.regions
          .where((region) => region.intersectsBounds(visibleBounds))
          .map((region) => region.id)
          .toSet();
      await _syncVisibleUnlockedPlaces();
    } catch (error) {
      message = 'Could not load nearby regions: $error';
      debugPrint('[MapController] Viewport loading error: $error');
    } finally {
      isLoadingViewport = false;
      notifyListeners();
    }
  }

  /// Whether a region's fog has been cleared, so its geometry is worth keeping.
  ///
  /// The region the user is standing in counts even before its unlock has
  /// persisted, because the dissipation animation needs its path to know where
  /// to tear.
  bool _isRegionCleared(String regionId) {
    return _fogClearedRegionIds.contains(regionId) ||
        currentRegion?.id == regionId;
  }

  /// Every region whose fog is cleared, used to narrow the viewport request.
  Set<String> _clearedRegionIds() {
    return <String>{..._fogClearedRegionIds, ?currentRegion?.id};
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
      _latestPosition = position;

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

  /// Returns the user's current GPS position.
  /// Throws if location access fails.
  Future<Position> getCurrentPosition() async {
    return _geoLocatorService.getCurrentLocation();
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

    unawaited(_awardVisitXpSafely());

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

      // Fixes the fog's world-space origin. Anchoring here rather than at the
      // globe origin keeps path coordinates in the low thousands, which is what
      // stops Float32 precision loss producing vertex jitter at high zoom.
      fogController
        ..setAnchor(userCenter)
        ..updateCamera(CameraPosition(target: userCenter, zoom: defaultZoom));

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

      await _moveCameraTo(position);

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

    final wasNewlyUnlocked = await _markRegionAsVisited(effectiveRegion);
    // Record an entry for heatmap counts (app opened / entered tile).
    await _recordRegionEntry(effectiveRegion);
    _refreshCachedPolygonsStyles();
    _visibleViewportRegionIds.add(effectiveRegion.id);

    _syncFogForCurrentRegion(
      region: effectiveRegion,
      wasNewlyUnlocked: wasNewlyUnlocked,
    );

    if (wasNewlyUnlocked) {
      _placeMarkerManager.setVisibleRegionIds(
        _visibleViewportRegionIds.intersection(_visitedRegionIds),
      );
      await _placeMarkerManager.loadPlacesForRegion(
        regionId: effectiveRegion.id,
        onPlaceTapped: onPlaceTapped,
      );
      markers = _placeMarkerManager.markers;
    }
    await _syncVisibleUnlockedPlaces();
  }

  /// Clears the fog over the region the user has just entered.
  ///
  /// A first unlock blows the clouds away from the user's position; re-entering
  /// an already-cleared region just ensures its hole exists, with no animation.
  ///
  /// [_latestPosition] is deliberately still null during [_loadInitialRegion],
  /// so a cold start into an unvisited tile clears without animating. Assigning
  /// it there would fire a dissipation nobody asked for every launch.
  void _syncFogForCurrentRegion({
    required RegionPolygon region,
    required bool wasNewlyUnlocked,
  }) {
    final position = _latestPosition;

    if (wasNewlyUnlocked && position != null) {
      fogController.startDissolve(
        region: region,
        userLatLng: LatLng(position.latitude, position.longitude),
      );
      return;
    }

    fogController.addClearedRegion(region);
  }

  Future<void> _syncVisibleUnlockedPlaces() async {
    final visibleUnlockedRegionIds = _visibleViewportRegionIds.intersection(
      _visitedRegionIds,
    );
    _placeMarkerManager.setVisibleRegionIds(visibleUnlockedRegionIds);
    markers = _placeMarkerManager.markers;

    if (visibleUnlockedRegionIds.isEmpty) return;

    isLoadingPlaces = true;
    notifyListeners();

    try {
      await _placeMarkerManager.loadPlacesForRegions(
        regionIds: visibleUnlockedRegionIds,
        onPlaceTapped: onPlaceTapped,
      );

      markers = _placeMarkerManager.markers;
    } catch (error) {
      message = 'Could not load visible places: $error';
      debugPrint('[MapController] Visible places loading error: $error');
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
        _handleLocationUpdate,
        onError: (Object error) {
          debugPrint('[MapController] Location updates error: $error');
        },
      );
    } catch (error) {
      debugPrint('[MapController] Could not start location updates: $error');
    }
  }

  void _handleLocationUpdate(Position position) {
    _latestPosition = position;
    // Couples wind speed to travel speed, so the clouds quicken when moving.
    fogController.setUserSpeed(position.speed);
    _queueRegionCheck(position);
    if (_isFollowingUser) {
      unawaited(_moveCameraTo(position));
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
      _fogClearedRegionIds = <String>{};
      _pendingFogReturnEvents = <String, DateTime>{};
      _visitCountsByRegion = <String, int>{};
      await _visitedRegionService.refreshFogDecayWarnings(
        difficulty: _fogDecayDifficulty,
      );
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
      _fogClearedRegionIds = await _visitedRegionService
          .loadFogClearedRegionIds(difficulty: _fogDecayDifficulty);
      _pendingFogReturnEvents = await _visitedRegionService
          .loadUnpresentedFogDecayEvents(difficulty: _fogDecayDifficulty);
      _fogClearedRegionIds.addAll(_pendingFogReturnEvents.keys);
      await _visitedRegionService.refreshFogDecayWarnings(
        difficulty: _fogDecayDifficulty,
      );
      debugPrint(
        '[MapController] Loaded ${_visitedRegionIds.length} visited regions',
      );
    } catch (error) {
      debugPrint('[MapController] Error loading visited regions: $error');
    }
  }

  void _startFogDecayRefresh() {
    _fogDecayRefreshTimer?.cancel();
    _fogDecayRefreshTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => unawaited(refreshFogDecayState()),
    );
  }

  /// Recomputes visual fog from persisted timestamps without changing history.
  Future<void> refreshFogDecayState() async {
    if (_userId == null) return;
    try {
      final clearedIds = await _visitedRegionService.loadFogClearedRegionIds(
        difficulty: _fogDecayDifficulty,
      );
      _fogClearedRegionIds = clearedIds;
      await _visitedRegionService.refreshFogDecayWarnings(
        difficulty: _fogDecayDifficulty,
      );
      fogController.retainClearedRegions(<String>{
        ...clearedIds,
        ...?fogController.returnTransition?.regionIds,
        ?currentRegion?.id,
      });
      notifyListeners();
    } catch (error) {
      debugPrint('[MapController] Error refreshing fog decay state: $error');
    }
  }

  /// Recomputes decay events after the app returns from the background.
  Future<void> handleAppResumed() async {
    if (_userId == null) return;
    final cleared = await _visitedRegionService.loadFogClearedRegionIds(
      difficulty: _fogDecayDifficulty,
    );
    final pending = await _visitedRegionService.loadUnpresentedFogDecayEvents(
      difficulty: _fogDecayDifficulty,
    );
    _pendingFogReturnEvents.addAll(pending);
    _fogClearedRegionIds = <String>{...cleared, ...pending.keys};
    await loadViewportRegions(force: true);
  }

  void _startPendingFogReturnAnimation() {
    final geometryIds = fogController.geometry?.regionIds.toSet() ?? <String>{};
    final currentId = currentRegion?.id;
    final renderable = _pendingFogReturnEvents.keys
        .where((id) => id != currentId && geometryIds.contains(id))
        .toSet();
    if (renderable.isEmpty) return;
    _fogClearedRegionIds.removeAll(renderable);
    fogController.startFogReturn(renderable);
  }

  void _handleFogReturnCompleted(Set<String> regionIds) {
    final presented = <String, DateTime>{};
    for (final id in regionIds) {
      final decayAt = _pendingFogReturnEvents.remove(id);
      if (decayAt != null) presented[id] = decayAt;
    }
    unawaited(_visitedRegionService.markFogDecayEventsPresented(presented));
  }

  /// Applies a changed preference and immediately recomputes visible fog.
  Future<void> updateFogDecayDifficulty(FogDecayDifficulty difficulty) async {
    if (_fogDecayDifficulty == difficulty) return;
    _fogDecayDifficulty = difficulty;
    await refreshFogDecayState();
    await handleAppResumed();
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
      _entryCountsByRegion = await _resolvedPolygonService
          .getPolygonEntryCounts(
            profileId: _userId!,
            validPolygonIds: _visitedRegionIds.isEmpty
                ? null
                : _visitedRegionIds,
          );

      debugPrint(
        '[MapController] Loaded entry counts for ${_entryCountsByRegion.length} SA1 regions',
      );
    } catch (error) {
      debugPrint(
        '[MapController] Error loading entry counts by region: $error',
      );
    }
  }

  Future<void> _recordRegionEntry(RegionPolygon region) async {
    if (_userId == null) return;

    try {
      // Optimistically update local cache so the heatmap updates immediately.
      _entryCountsByRegion.update(region.id, (c) => c + 1, ifAbsent: () => 1);

      await _resolvedExplorationStatsService.recordReentry(
        profileId: _userId!,
        polygonId: region.id,
      );
      await _visitedRegionService.refreshFogDecayWarnings(
        difficulty: _fogDecayDifficulty,
      );
    } catch (error) {
      debugPrint('[MapController] Error recording region entry: $error');
    }
  }

  Future<bool> _markRegionAsVisited(RegionPolygon region) async {
    final regionId = region.id;

    if (_visitedRegionIds.contains(regionId)) {
      _fogClearedRegionIds.add(regionId);
      final pendingDecay = _pendingFogReturnEvents.remove(regionId);
      if (pendingDecay != null) {
        unawaited(
          _visitedRegionService.markFogDecayEventsPresented(<String, DateTime>{
            regionId: pendingDecay,
          }),
        );
      }
      return false;
    }

    try {
      final didPersistVisit = await _resolvedExplorationStatsService
          .recordUnlock(profileId: _userId!, region: region);

      if (!didPersistVisit) {
        return false;
      }

      _visitedRegionIds.add(regionId);
      _fogClearedRegionIds.add(regionId);

      final xpResult = await _awardUnlockXp(region);

      // Only surface "+XP" feedback when the canonical award actually persisted.
      if (xpResult != null && xpResult.succeeded) {
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
}
