/*
 * Author: Amarprit Singh
 * Last Updated: 29 August 2026
 * Description:
 *   A shared post stores its route but not its distance, so the distance on a
 *   share card is measured back off the polyline. These cover the legs that
 *   measurement sums and the routes too short to have any length at all.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/journeys/data/polyline_codec.dart';
import 'package:roam_io/features/journeys/data/route_distance.dart';

const _start = LatLng(-37.8136, 144.9631);
const _middle = LatLng(-37.8036, 144.9731);
const _end = LatLng(-37.7936, 144.9831);

void main() {
  group('routeDistanceMeters', () {
    test('measures a known leg', () {
      // A degree of latitude is ~111.19 km on the 6371 km sphere used here.
      expect(
        routeDistanceMeters(const [LatLng(0, 0), LatLng(1, 0)]),
        closeTo(111194.9, 1),
      );
    });

    test('sums every leg of the route', () {
      final whole = routeDistanceMeters(const [_start, _middle, _end]);
      final legs =
          routeDistanceMeters(const [_start, _middle]) +
          routeDistanceMeters(const [_middle, _end]);

      expect(whole, closeTo(legs, 0.001));
    });

    test('a route of fewer than two points covers no ground', () {
      expect(routeDistanceMeters(const []), 0);
      expect(routeDistanceMeters(const [_start]), 0);
    });

    test('standing still covers no ground', () {
      expect(routeDistanceMeters(const [_start, _start]), 0);
    });
  });

  group('encodedRouteDistanceMeters', () {
    test('decodes the polyline before measuring it', () {
      const points = [_start, _middle, _end];

      // Polyline encoding rounds to five decimal places, so the decoded route
      // measures within a metre of the points that went in.
      expect(
        encodedRouteDistanceMeters(PolylineCodec.encode(points)),
        closeTo(routeDistanceMeters(points), 1),
      );
    });

    test('an unrecorded route has no distance', () {
      expect(encodedRouteDistanceMeters(''), 0);
      expect(encodedRouteDistanceMeters(null), 0);
    });
  });
}
