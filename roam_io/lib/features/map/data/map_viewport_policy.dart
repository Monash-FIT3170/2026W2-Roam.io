import 'package:google_maps_flutter/google_maps_flutter.dart';

enum MapLayerMode {
  overview,
  tileDetail,
}

class MapViewportPolicy {
  static const double defaultZoom = 16.0;
  static const double minimumTileDetailZoom = 15.0;

  static const int debounceMilliseconds = 700;
  static const double viewportPaddingRatio = 0.25;

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

    final latPadding = latSpan * viewportPaddingRatio;
    final lngPadding = lngSpan * viewportPaddingRatio;

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

  bool areBoundsSimilar(LatLngBounds oldBounds, LatLngBounds newBounds) {
    final latSpan = oldBounds.northeast.latitude - oldBounds.southwest.latitude;
    final lngSpan = oldBounds.northeast.longitude - oldBounds.southwest.longitude;

    final latThreshold = latSpan.abs() * 0.2;
    final lngThreshold = lngSpan.abs() * 0.2;

    final southDiff =
        (newBounds.southwest.latitude - oldBounds.southwest.latitude).abs();
    final westDiff =
        (newBounds.southwest.longitude - oldBounds.southwest.longitude).abs();
    final northDiff =
        (newBounds.northeast.latitude - oldBounds.northeast.latitude).abs();
    final eastDiff =
        (newBounds.northeast.longitude - oldBounds.northeast.longitude).abs();

    return southDiff < latThreshold &&
        westDiff < lngThreshold &&
        northDiff < latThreshold &&
        eastDiff < lngThreshold;
  }
}