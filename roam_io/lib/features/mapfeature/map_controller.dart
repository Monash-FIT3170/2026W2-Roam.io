// Coordinates map state, location updates, region loading, and visited-region
// styling in one controller. This gives the page a single place to manage
// map behavior without pushing orchestration into widgets.

import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'region_polygon.dart';
import 'region_polygon_cache.dart';
import 'region_service.dart';
import 'visited_region_service.dart';
import 'geolocator_service.dart';

class MapController extends ChangeNotifier {
  static const LatLng fallbackCenter = LatLng(
    -37.8136,
    144.9631,
  ); // fallback defined for Melbourne CBD if user location is not available

  // storing the file path for the custom map render which will apply everywhere
  // we apply transparent polygon styling for polygons visited and a darker grey polygon styling for unvisited
  static const String _visitedTilesStyleAsset =
      'assets/map_styles/visited_tiles.json';

  static const double defaultZoom = 13.5;

  final GeoLocatorService _geoLocatorService;
  final RegionService _regionService;
  final VisitedRegionService _visitedRegionService;
  final RegionPolygonCache _polygonCacheManager;

  MapController({
    GeoLocatorService? geoLocatorService,
    RegionService? regionService,
    VisitedRegionService? visitedRegionService,
    RegionPolygonCache? polygonCacheManager,
  }) : _geoLocatorService = geoLocatorService ?? GeoLocatorService(),
       _regionService = regionService ?? RegionService(),
       _visitedRegionService = visitedRegionService ?? VisitedRegionService(),
       _polygonCacheManager = polygonCacheManager ?? RegionPolygonCache();

  GoogleMapController? _googleMapController;
  StreamSubscription<Position>? _locationSubscription;

  LatLng center = fallbackCenter;
  String? mapStyle;
  bool myLocationEnabled = false;
  bool isLoading = true;
  bool isLoadingViewport = false;
  String? message;
  Set<String> visitedPolygonIds = <String>{};

  RegionPolygon? currentRegion;
  Set<Polygon> polygons = {};

  LatLngBounds? _lastLoadedBounds;
  DateTime? _lastViewportLoadTime;

  Future<void> initialise() async {
    await _loadMapStyle();
    await _loadVisitedPolygonIds();
    await _loadInitialRegion();
    await _startLocationUpdates();
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

    await loadViewportRegions();
  }

  Future<void> _loadMapStyle() async {
    try {
      mapStyle = await rootBundle.loadString(_visitedTilesStyleAsset);
    } catch (e) {
      message = 'Failed to load map style';
      notifyListeners();
    }
  }

  Future<void> _loadVisitedPolygonIds() async {
    try {
      visitedPolygonIds = await _visitedRegionService.loadVisitedRegionIds();
      _refreshCachedPolygonStyles();
    } catch (e) {
      visitedPolygonIds = {};
      message = 'Failed to load visited polygons';
      notifyListeners();
    }
  }

  Future<void> _loadInitialRegion() async {
    try {
      final Position position = await _geoLocatorService.getCurrentLocation();

      final userCenter = LatLng(position.latitude, position.longitude);

      center = userCenter;
      myLocationEnabled = true;
      isLoading = false;

      notifyListeners();

      await _googleMapController?.animateCamera(
        CameraUpdate.newLatLngZoom(userCenter, defaultZoom),
      );

      await _loadCurrentRegionForPosition(position);
    } catch (error) {
      center = fallbackCenter;
      isLoading = false;
      myLocationEnabled = false;
      message = 'Could not load your location: $error';

      notifyListeners();
    }
  }

  Future<void> _loadCurrentRegionForPosition(Position position) async {
    try {
      final region = await _regionService.getContainingRegion(
        lat: position.latitude,
        lng: position.longitude,
      );

      final previousRegionId = currentRegion?.id;
      currentRegion = region;

      if (region == null) {
        message = 'Location found, but no SA2 region was found';
      } else {
        if (previousRegionId != region.id) {
          await _markRegionVisited(region.id);
        }
        message = region.name;
        _polygonCacheManager.cacheRegion(
          region: region,
          isVisited: _shouldRenderRegionAsVisited(region.id),
          onRegionTapped: onRegionTapped,
        );
      }

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
        final wasAdded = _polygonCacheManager.cacheRegion(
          region: region,
          isVisited: _shouldRenderRegionAsVisited(region.id),
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

  bool _shouldRenderRegionAsVisited(String regionId) {
    return currentRegion?.id == regionId || _isRegionVisited(regionId);
  }

  Future<void> _markRegionVisited(String regionId) async {
    final wasMarked = await _visitedRegionService.markVisited(
      regionId,
      visitedAt: DateTime.now(),
    );

    if (wasMarked) {
      visitedPolygonIds = <String>{...visitedPolygonIds, regionId};
      _refreshCachedPolygonStyles();
    }
  }

  void _refreshCachedPolygonStyles() {
    _polygonCacheManager.refreshStyles(
      shouldRenderAsVisited: _shouldRenderRegionAsVisited,
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
}
