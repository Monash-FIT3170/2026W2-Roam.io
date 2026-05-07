/*
 * Author: Rushil Patel
 * Last Modified: 27/04/2026
 * Description:
 *   Manages map location state, region polygon loading, viewport caching, and
 *   Google Maps controller coordination.
 */

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'RegionPolygon.dart';
import 'RegionService.dart';
import 'geolocator_service.dart';

/// Coordinates map state, location lookup, and region polygon loading.
class MapController extends ChangeNotifier {
  /// Melbourne fallback center used when location lookup is unavailable.
  static const LatLng fallbackCenter = LatLng(-37.8136, 144.9631);

  /// Default zoom level for initial map positioning.
  static const double defaultZoom = 13.5;

  final GeoLocatorService _geoLocatorService;
  final RegionService _regionService;

  MapController({
    GeoLocatorService? geoLocatorService,
    RegionService? regionService,
  }) : _geoLocatorService = geoLocatorService ?? GeoLocatorService(),
       _regionService = regionService ?? RegionService();

  GoogleMapController? _googleMapController;

  LatLng center = fallbackCenter;
  bool myLocationEnabled = false;
  bool isLoading = true;
  bool isLoadingViewport = false;
  String? message;

  RegionPolygon? currentRegion;
  Set<Polygon> polygons = {};

  // Region and polygon caches prevent repeated API fetches for known areas.
  final Map<String, RegionPolygon> _regionCache = {};
  final Map<String, Polygon> _polygonCache = {};

  LatLngBounds? _lastLoadedBounds;
  DateTime? _lastViewportLoadTime;

  /// Loads the current location and containing region for the initial map view.
  Future<void> initialise() async {
    await _loadInitialRegion();
  }

  /// Releases the Google Maps controller when the hosting widget is disposed.
  Future<void> disposeController() async {
    _googleMapController?.dispose();
  }

  /// Stores the Google Maps controller and loads polygons for the first view.
  Future<void> onMapCreated(GoogleMapController controller) async {
    _googleMapController = controller;

    await _googleMapController?.animateCamera(
      CameraUpdate.newLatLngZoom(center, defaultZoom),
    );

    await loadViewportRegions();
  }

  Future<void> _loadInitialRegion() async {
    try {
      final Position position = await _geoLocatorService.getCurrentLocation();

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
        _cacheRegionAsPolygons(
          region: region,
          strokeColor: const Color(0xFFC084FC),
          fillColor: const Color(0x228B5CF6),
          strokeWidth: 5,
        );
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

  /// Loads and caches region polygons visible in the current map viewport.
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
          fillColor: const Color(0x990F172A),
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

  /// Updates the selected region message when a polygon is tapped.
  void onRegionTapped(String regionId, String regionName) {
    message = regionName;
    notifyListeners();
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
}
