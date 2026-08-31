/*
 * Author: Amarprit Singh
 * Last Updated: 29 August 2026
 * Description:
 *   Great-circle length of a recorded route. An activity post stores the
 *   polyline it was recorded from but never its distance, so anything built
 *   from a post has to measure the route back off that polyline.
 */

import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'polyline_codec.dart';

const double _earthRadiusMeters = 6371000;

/// Distance travelled along [points], in metres.
///
/// Fewer than two points is no distance at all, which is what a stationary or
/// unrecorded route should report.
double routeDistanceMeters(List<LatLng> points) {
  var total = 0.0;
  for (var index = 1; index < points.length; index++) {
    total += _haversineMeters(points[index - 1], points[index]);
  }
  return total;
}

/// Distance travelled along an encoded polyline, in metres.
double encodedRouteDistanceMeters(String? encodedRoute) {
  if (encodedRoute == null || encodedRoute.isEmpty) return 0;
  return routeDistanceMeters(PolylineCodec.decode(encodedRoute));
}

double _haversineMeters(LatLng from, LatLng to) {
  final fromLatRad = from.latitude * math.pi / 180;
  final toLatRad = to.latitude * math.pi / 180;
  final deltaLat = (to.latitude - from.latitude) * math.pi / 180;
  final deltaLng = (to.longitude - from.longitude) * math.pi / 180;

  final a =
      math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
      math.cos(fromLatRad) *
          math.cos(toLatRad) *
          math.sin(deltaLng / 2) *
          math.sin(deltaLng / 2);

  return _earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
