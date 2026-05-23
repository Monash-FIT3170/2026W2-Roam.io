import 'package:google_maps_flutter/google_maps_flutter.dart';


/*
 * Author: Rushil Patel
 * Description:
 *   Centralises map zoom behaviour and viewport-loading rules.
 *   Determines when the map should display detailed SA1 tiles versus
 *   overview mode, and provides viewport expansion logic used for
 *   prefetching nearby regions before they enter the visible screen.
 */


enum MapLayerMode {
  sa3Overview,
  sa1Detail,
}

class MapViewportPolicy {
  static const double defaultZoom = 16.0;

  // Hysteresis:
  // SA1 -> SA3 only when zoomed far out.
  // SA3 -> SA1 only when zoomed clearly back in.
  static const double sa1ExitZoom = 12.75;
  static const double sa1EnterZoom = 13.75;

  static const int debounceMilliseconds = 650;
  static const double sa1PrefetchPaddingRatio = 1.25;

  MapLayerMode modeForZoom({
    required double zoom,
    required MapLayerMode currentMode,
  }) {
    if (currentMode == MapLayerMode.sa1Detail) {
      return zoom < sa1ExitZoom
          ? MapLayerMode.sa3Overview
          : MapLayerMode.sa1Detail;
    }

    return zoom > sa1EnterZoom
        ? MapLayerMode.sa1Detail
        : MapLayerMode.sa3Overview;
  }

  LatLngBounds expandSa1Bounds(LatLngBounds bounds) {
    final latSpan = bounds.northeast.latitude - bounds.southwest.latitude;
    final lngSpan = bounds.northeast.longitude - bounds.southwest.longitude;

    final latPadding = latSpan.abs() * sa1PrefetchPaddingRatio;
    final lngPadding = lngSpan.abs() * sa1PrefetchPaddingRatio;

    return LatLngBounds(
      southwest: LatLng(
        bounds.southwest.latitude - latPadding,
        bounds.southwest.longitude - lngPadding,
      ),
      northeast: LatLng(
        bounds.northeast.latitude + latPadding,
        bounds.northeast.longitude + lngPadding,
      ),
    );
  }

  bool containsBounds({
    required LatLngBounds outer,
    required LatLngBounds inner,
  }) {
    return inner.southwest.latitude >= outer.southwest.latitude &&
        inner.southwest.longitude >= outer.southwest.longitude &&
        inner.northeast.latitude <= outer.northeast.latitude &&
        inner.northeast.longitude <= outer.northeast.longitude;
  }
}