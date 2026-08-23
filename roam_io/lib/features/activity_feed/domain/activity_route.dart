/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 21 August 2026
 * Description:
 *   Prepares Journey route data for completion and activity map previews
 *   without reading private Journey documents or live location streams.
 */

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../journeys/data/polyline_codec.dart';
import '../models/activity_feed_item.dart';

/// Parsed route data ready for compact, detail, or expanded map rendering.
class ActivityRoute {
  const ActivityRoute({
    required this.points,
    required this.bounds,
    required this.center,
    required this.start,
    required this.finish,
  });

  static const double _minimumSpanDegrees = 0.003;

  final List<LatLng> points;
  final LatLngBounds bounds;
  final LatLng center;
  final LatLng start;
  final LatLng finish;

  /// Builds route display data from persisted social activity route fields.
  static ActivityRoute? tryCreate({
    required String? encodedRoute,
    required ActivityRouteBounds? persistedBounds,
  }) {
    final encoded = encodedRoute?.trim();
    if (encoded == null || encoded.isEmpty) return null;

    final points = _decodeRoute(encoded);
    if (points.isEmpty) return null;

    final rawBounds =
        _validPersistedBounds(persistedBounds) ?? _boundsFromPoints(points);
    final fittedBounds = _expandTinyBounds(rawBounds);
    final center = LatLng(
      (fittedBounds.southwest.latitude + fittedBounds.northeast.latitude) / 2,
      (fittedBounds.southwest.longitude + fittedBounds.northeast.longitude) / 2,
    );

    return ActivityRoute(
      points: List<LatLng>.unmodifiable(points),
      bounds: fittedBounds,
      center: center,
      start: points.first,
      finish: points.last,
    );
  }

  /// Builds route display data from the active Journey's complete GPS points.
  static ActivityRoute? fromPoints(List<LatLng> routePoints) {
    final points = routePoints
        .where(_isValidCoordinate)
        .toList(growable: false);
    if (points.isEmpty) return null;

    final fittedBounds = _expandTinyBounds(_boundsFromPoints(points));
    final center = LatLng(
      (fittedBounds.southwest.latitude + fittedBounds.northeast.latitude) / 2,
      (fittedBounds.southwest.longitude + fittedBounds.northeast.longitude) / 2,
    );

    return ActivityRoute(
      points: List<LatLng>.unmodifiable(points),
      bounds: fittedBounds,
      center: center,
      start: points.first,
      finish: points.last,
    );
  }

  static List<LatLng> _decodeRoute(String encodedRoute) {
    try {
      return PolylineCodec.decode(
        encodedRoute,
      ).where(_isValidCoordinate).toList(growable: false);
    } catch (_) {
      return const <LatLng>[];
    }
  }

  static LatLngBounds? _validPersistedBounds(ActivityRouteBounds? bounds) {
    if (bounds == null) return null;
    final southwest = LatLng(
      bounds.southwestLatitude,
      bounds.southwestLongitude,
    );
    final northeast = LatLng(
      bounds.northeastLatitude,
      bounds.northeastLongitude,
    );
    if (!_isValidCoordinate(southwest) || !_isValidCoordinate(northeast)) {
      return null;
    }
    if (southwest.latitude > northeast.latitude ||
        southwest.longitude > northeast.longitude) {
      return null;
    }
    return LatLngBounds(southwest: southwest, northeast: northeast);
  }

  static LatLngBounds _boundsFromPoints(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  static LatLngBounds _expandTinyBounds(LatLngBounds bounds) {
    final latSpan = bounds.northeast.latitude - bounds.southwest.latitude;
    final lngSpan = bounds.northeast.longitude - bounds.southwest.longitude;
    final targetLatSpan = latSpan < _minimumSpanDegrees
        ? _minimumSpanDegrees
        : latSpan;
    final targetLngSpan = lngSpan < _minimumSpanDegrees
        ? _minimumSpanDegrees
        : lngSpan;
    if (targetLatSpan == latSpan && targetLngSpan == lngSpan) return bounds;

    final centerLat =
        (bounds.southwest.latitude + bounds.northeast.latitude) / 2;
    final centerLng =
        (bounds.southwest.longitude + bounds.northeast.longitude) / 2;
    final halfLat = targetLatSpan / 2;
    final halfLng = targetLngSpan / 2;

    return LatLngBounds(
      southwest: LatLng(
        (centerLat - halfLat).clamp(-90, 90).toDouble(),
        (centerLng - halfLng).clamp(-180, 180).toDouble(),
      ),
      northeast: LatLng(
        (centerLat + halfLat).clamp(-90, 90).toDouble(),
        (centerLng + halfLng).clamp(-180, 180).toDouble(),
      ),
    );
  }

  static bool _isValidCoordinate(LatLng point) {
    return point.latitude >= -90 &&
        point.latitude <= 90 &&
        point.longitude >= -180 &&
        point.longitude <= 180;
  }
}
