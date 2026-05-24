import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'map_viewport_policy.dart';
import 'region_polygon.dart';
import 'region_service.dart';

/*
 * Author: Rushil Patel
 * Description:
 *   Handles viewport-based region loading for the map feature.
 *   Tracks previously loaded map coverage, applies viewport
 *   prefetching rules, and prevents unnecessary network requests
 *   when the current screen area has already been cached.
 */

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

/// Loads nearby SA1 tiles only.
///
/// SA3 is preloaded separately in MapController using getAllSa3Regions().
class ViewportRegionLoader {
  ViewportRegionLoader({
    RegionService? regionService,
    MapViewportPolicy? policy,
  }) : _regionService = regionService ?? RegionService(),
       _policy = policy ?? MapViewportPolicy();

  final RegionService _regionService;
  final MapViewportPolicy _policy;

  LatLngBounds? _loadedSa1CoverageBounds;
  DateTime? _lastLoadTime;
  bool _isLoading = false;

  Future<ViewportRegionLoadResult> load({
    required GoogleMapController mapController,
    required double currentZoom,
    required MapLayerMode currentMode,
    bool force = false,
  }) async {
    final targetMode = _policy.modeForZoom(
      zoom: currentZoom,
      currentMode: currentMode,
    );

    if (targetMode == MapLayerMode.sa3Overview) {
      return const ViewportRegionLoadResult(
        regions: [],
        mode: MapLayerMode.sa3Overview,
        didSkip: true,
      );
    }

    if (!force && (_isLoading || _isInsideDebounceWindow())) {
      return const ViewportRegionLoadResult(
        regions: [],
        mode: MapLayerMode.sa1Detail,
        didSkip: true,
      );
    }

    final visibleBounds = await mapController.getVisibleRegion();

    if (!force &&
        _loadedSa1CoverageBounds != null &&
        _policy.containsBounds(
          outer: _loadedSa1CoverageBounds!,
          inner: visibleBounds,
        )) {
      return const ViewportRegionLoadResult(
        regions: [],
        mode: MapLayerMode.sa1Detail,
        didSkip: true,
      );
    }

    final prefetchBounds = _policy.expandSa1Bounds(visibleBounds);

    _isLoading = true;

    try {
      final regions = await _regionService.getRegionsForViewport(
        south: prefetchBounds.southwest.latitude,
        west: prefetchBounds.southwest.longitude,
        north: prefetchBounds.northeast.latitude,
        east: prefetchBounds.northeast.longitude,
      );

      _loadedSa1CoverageBounds = prefetchBounds;
      _lastLoadTime = DateTime.now();

      debugPrint(
        '[ViewportRegionLoader] Prefetched ${regions.length} SA1 tiles '
        'at zoom $currentZoom force=$force',
      );

      return ViewportRegionLoadResult(
        regions: regions,
        mode: MapLayerMode.sa1Detail,
        didSkip: false,
        message: 'Loaded ${regions.length} nearby SA1 tiles',
      );
    } finally {
      _isLoading = false;
    }
  }

  bool _isInsideDebounceWindow() {
    if (_lastLoadTime == null) return false;

    final difference = DateTime.now().difference(_lastLoadTime!);

    return difference.inMilliseconds < MapViewportPolicy.debounceMilliseconds;
  }
}
