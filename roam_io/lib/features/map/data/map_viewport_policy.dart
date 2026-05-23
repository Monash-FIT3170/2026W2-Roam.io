import 'package:google_maps_flutter/google_maps_flutter.dart';

enum MapLayerMode {
  overview,
  tileDetail,
}

class MapViewportPolicy {
  static const double defaultZoom = 16.0;
  static const double minimumTileDetailZoom = 15.0;

  static const int debounceMilliseconds = 650;

  // Loads extra area around the visible screen so nearby panning feels smooth.
  static const double prefetchPaddingRatio = 0.75;

  static const String zoomInMessage = 'Zoom in to reveal SA1 tiles';

  MapLayerMode modeForZoom(double zoom) {
    return zoom >= minimumTileDetailZoom
        ? MapLayerMode.tileDetail
        : MapLayerMode.overview;
  }

  bool shouldLoadSa1Tiles(double zoom) {
    return modeForZoom(zoom) == MapLayerMode.tileDetail;
  }

  LatLngBounds expandBounds(LatLngBounds bounds) {
    final latSpan = bounds.northeast.latitude - bounds.southwest.latitude;
    final lngSpan = bounds.northeast.longitude - bounds.southwest.longitude;

    final latPadding = latSpan.abs() * prefetchPaddingRatio;
    final lngPadding = lngSpan.abs() * prefetchPaddingRatio;

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