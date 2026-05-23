import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'map_viewport_policy.dart';
import 'region_polygon.dart';
import 'region_service.dart';

class ViewportRegionLoadResult {
  const ViewportRegionLoadResult({
    required this.regions,
    required this.mode,
    required this.didSkip,
    this.message,
  });

  final List<RegionPolygon> regions;
  final MapLayerMode mode;
  final bool didSkip;
  final String? message;
}

class ViewportRegionLoader {
  ViewportRegionLoader({
    RegionService? regionService,
    MapViewportPolicy? policy,
  })  : _regionService = regionService ?? RegionService(),
        _policy = policy ?? MapViewportPolicy();

  final RegionService _regionService;
  final MapViewportPolicy _policy;

  LatLngBounds? _lastLoadedBounds;
  DateTime? _lastLoadTime;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  Future<ViewportRegionLoadResult> load({
    required GoogleMapController mapController,
    required double currentZoom,
  }) async {
    final mode = _policy.modeForZoom(currentZoom);

    if (!_policy.shouldLoadSa1Tiles(currentZoom)) {
      return const ViewportRegionLoadResult(
        regions: [],
        mode: MapLayerMode.overview,
        didSkip: true,
        message: MapViewportPolicy.zoomInMessage,
      );
    }

    if (_isLoading || _isInsideDebounceWindow()) {
      return ViewportRegionLoadResult(
        regions: const [],
        mode: mode,
        didSkip: true,
      );
    }

    final visibleBounds = await mapController.getVisibleRegion();
    final expandedBounds = _policy.expandBounds(visibleBounds);

    if (_lastLoadedBounds != null &&
        _policy.areBoundsSimilar(_lastLoadedBounds!, expandedBounds)) {
      return ViewportRegionLoadResult(
        regions: const [],
        mode: mode,
        didSkip: true,
        message: 'Already loaded this area',
      );
    }

    _isLoading = true;

    try {
      final regions = await _regionService.getRegionsForViewport(
        south: expandedBounds.southwest.latitude,
        west: expandedBounds.southwest.longitude,
        north: expandedBounds.northeast.latitude,
        east: expandedBounds.northeast.longitude,
      );

      _lastLoadedBounds = expandedBounds;

      debugPrint(
        '[ViewportRegionLoader] Loaded ${regions.length} regions at zoom $currentZoom',
      );

      return ViewportRegionLoadResult(
        regions: regions,
        mode: mode,
        didSkip: false,
        message: 'Loaded ${regions.length} nearby tiles',
      );
    } finally {
      _isLoading = false;
    }
  }

  bool _isInsideDebounceWindow() {
    final now = DateTime.now();

    if (_lastLoadTime == null) {
      _lastLoadTime = now;
      return false;
    }

    final diff = now.difference(_lastLoadTime!);

    if (diff.inMilliseconds < MapViewportPolicy.debounceMilliseconds) {
      return true;
    }

    _lastLoadTime = now;
    return false;
  }
}