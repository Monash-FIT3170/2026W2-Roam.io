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

  LatLngBounds? _loadedCoverageBounds;
  DateTime? _lastLoadTime;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  Future<ViewportRegionLoadResult> load({
    required GoogleMapController mapController,
    required double currentZoom,
    bool force = false,
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

    if (!force && (_isLoading || _isInsideDebounceWindow())) {
      return ViewportRegionLoadResult(
        regions: const [],
        mode: mode,
        didSkip: true,
      );
    }

    final visibleBounds = await mapController.getVisibleRegion();

    if (!force &&
        _loadedCoverageBounds != null &&
        _policy.containsBounds(
          outer: _loadedCoverageBounds!,
          inner: visibleBounds,
        )) {
      return ViewportRegionLoadResult(
        regions: const [],
        mode: mode,
        didSkip: true,
      );
    }

    final prefetchBounds = _policy.expandBounds(visibleBounds);

    _isLoading = true;

    try {
      final regions = await _regionService.getRegionsForViewport(
        south: prefetchBounds.southwest.latitude,
        west: prefetchBounds.southwest.longitude,
        north: prefetchBounds.northeast.latitude,
        east: prefetchBounds.northeast.longitude,
      );

      _loadedCoverageBounds = prefetchBounds;
      _lastLoadTime = DateTime.now();

      debugPrint(
        '[ViewportRegionLoader] Prefetched ${regions.length} SA1 tiles '
        'at zoom $currentZoom force=$force',
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
      return false;
    }

    final difference = now.difference(_lastLoadTime!);

    return difference.inMilliseconds < MapViewportPolicy.debounceMilliseconds;
  }
}