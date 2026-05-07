import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'PlaceOfInterest.dart';
import 'PlacesService.dart';
import 'RegionPolygon.dart';
import 'RegionService.dart';
import 'geolocator_service.dart';

class MapController extends ChangeNotifier {
  static const LatLng fallbackCenter = LatLng(-37.8136, 144.9631);

  static const double defaultZoom = 13.5;

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

  MapController({
    GeoLocatorService? geoLocatorService,
    RegionService? regionService,
    PlacesService? placesService,
  })  : _geoLocatorService = geoLocatorService ?? GeoLocatorService(),
        _regionService = regionService ?? RegionService(),
        _placesService = placesService ?? PlacesService();

  GoogleMapController? _googleMapController;

  LatLng center = fallbackCenter;
  bool myLocationEnabled = false;
  bool isLoading = true;
  bool isLoadingViewport = false;
  bool isLoadingPlaces = false;
  String? message;

  

  RegionPolygon? currentRegion;
  Set<Polygon> polygons = {};
  Set<Marker> markers = {};


  // cache regions and polygons to avoid constant re-fetching
  final Map<String, RegionPolygon> _regionCache = {};
  final Map<String, Polygon> _polygonCache = {};

  // cache places to avoid re-fetching (key = regionId)
  final Map<String, List<PlaceOfInterest>> _placesCache = {};

  LatLngBounds? _lastLoadedBounds;
  DateTime? _lastViewportLoadTime;




  Future<void> initialise() async {
    // Pre-load circle icons for all place categories
    await PlaceOfInterest.preloadIcons();
    await _loadInitialRegion();
  }

  Future<void> disposeController() async {
    _googleMapController?.dispose();
  }

  Future<void> onMapCreated(GoogleMapController controller) async {
    _googleMapController = controller;

    await _googleMapController?.setMapStyle(_mapStyle);

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
      final Position position = await _geoLocatorService.getCurrentLocation();

      final userCenter = LatLng(
        position.latitude,
        position.longitude,
      );

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
        _cacheRegionAsPolygons(
          region: region,
          strokeColor: const Color(0xFFC084FC), 
          fillColor: const Color(0x228B5CF6),
          strokeWidth: 5,
        );

        // Load places for the current (unlocked) region
        await _loadPlacesForRegion(region.id);
      }

      polygons = _polygonCache.values.toSet();

      notifyListeners();

      await _googleMapController?.animateCamera(
        CameraUpdate.newLatLngZoom(userCenter, defaultZoom),
      );
    } catch (error) {
      center = fallbackCenter;
      isLoading = false;
      myLocationEnabled = false;
      message = 'Could not load location/region: $error';

      notifyListeners();
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
        final wasAdded = _cacheRegionAsPolygons(
          region: region,
          strokeColor: const Color(0xFF94A3B8),
          fillColor: const Color(0x990F172A), //simulate fake fog 
          strokeWidth: 2,
        );

        if (wasAdded) {
          newRegionCount++;
        }
      }

      polygons = _polygonCache.values.toSet();
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




  bool _cacheRegionAsPolygons({
    required RegionPolygon region,
    required Color strokeColor,
    required Color fillColor,
    required int strokeWidth,
  }) {
    if (_regionCache.containsKey(region.id)) {
      return false;
    }

    _regionCache[region.id] = region;

    final googlePolygons = region.toGooglePolygons(
      strokeColor: strokeColor,
      fillColor: fillColor,
      strokeWidth: strokeWidth,
      onTap: onRegionTapped,
    );

    for (final polygon in googlePolygons) {
      _polygonCache[polygon.polygonId.value] = polygon;
    }

    return true;
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

    final southDiff = (
      newBounds.southwest.latitude - oldBounds.southwest.latitude
    ).abs();

    final westDiff = (
      newBounds.southwest.longitude - oldBounds.southwest.longitude
    ).abs();

    final northDiff = (
      newBounds.northeast.latitude - oldBounds.northeast.latitude
    ).abs();

    final eastDiff = (
      newBounds.northeast.longitude - oldBounds.northeast.longitude
    ).abs();

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
      debugPrint('[MapController] Cache hit - ${_placesCache[regionId]!.length} places');
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
        allMarkers.add(
          place.toMarker(onTap: onPlaceTapped),
        );
      }
    }

    markers = allMarkers;
  }


  /// Called when a place marker is tapped.
  void onPlaceTapped(PlaceOfInterest place) {
    message = '${place.name} • ${place.category.displayName}';
    notifyListeners();
  }
}