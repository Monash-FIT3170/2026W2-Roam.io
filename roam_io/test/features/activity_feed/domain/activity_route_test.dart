/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 21 August 2026
 * Description:
 *   Unit tests for preparing persisted and in-memory Journey route data for
 *   map previews without reading private Journey state.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/activity_feed/domain/activity_route.dart';
import 'package:roam_io/features/activity_feed/models/activity_feed_item.dart';
import 'package:roam_io/features/journeys/data/polyline_codec.dart';

void main() {
  test('valid persisted bounds are reused', () {
    final route = ActivityRoute.tryCreate(
      encodedRoute: _encodedRoute,
      persistedBounds: const ActivityRouteBounds(
        southwestLatitude: -37.82,
        southwestLongitude: 144.96,
        northeastLatitude: -37.81,
        northeastLongitude: 144.98,
      ),
    );

    expect(route, isNotNull);
    expect(route!.bounds.southwest.latitude, -37.82);
    expect(route.bounds.southwest.longitude, 144.96);
    expect(route.bounds.northeast.latitude, -37.81);
    expect(route.bounds.northeast.longitude, 144.98);
    expect(route.points, hasLength(3));
  });

  test('missing bounds are computed from decoded route', () {
    final route = ActivityRoute.tryCreate(
      encodedRoute: _encodedRoute,
      persistedBounds: null,
    );

    expect(route, isNotNull);
    expect(route!.bounds.southwest.latitude, lessThanOrEqualTo(-37.8136));
    expect(route.bounds.southwest.longitude, lessThanOrEqualTo(144.9631));
    expect(route.bounds.northeast.latitude, greaterThanOrEqualTo(-37.8118));
    expect(route.bounds.northeast.longitude, greaterThanOrEqualTo(144.9690));
  });

  test('one-point route produces safe padded bounds', () {
    final encoded = PolylineCodec.encode(const [LatLng(-37.8136, 144.9631)]);

    final route = ActivityRoute.tryCreate(
      encodedRoute: encoded,
      persistedBounds: null,
    );

    expect(route, isNotNull);
    final latSpan =
        route!.bounds.northeast.latitude - route.bounds.southwest.latitude;
    final lngSpan =
        route.bounds.northeast.longitude - route.bounds.southwest.longitude;
    expect(latSpan, closeTo(0.003, 0.0000001));
    expect(lngSpan, closeTo(0.003, 0.0000001));
    expect(route.start, route.finish);
  });

  test('identical-point route produces safe padded bounds', () {
    final encoded = PolylineCodec.encode(const [
      LatLng(-37.8136, 144.9631),
      LatLng(-37.8136, 144.9631),
    ]);

    final route = ActivityRoute.tryCreate(
      encodedRoute: encoded,
      persistedBounds: null,
    );

    expect(route, isNotNull);
    expect(
      route!.bounds.northeast.latitude - route.bounds.southwest.latitude,
      closeTo(0.003, 0.0000001),
    );
    expect(
      route.bounds.northeast.longitude - route.bounds.southwest.longitude,
      closeTo(0.003, 0.0000001),
    );
  });

  test('malformed and empty encoded routes produce no usable map', () {
    expect(
      ActivityRoute.tryCreate(encodedRoute: '', persistedBounds: null),
      isNull,
    );
    expect(
      ActivityRoute.tryCreate(
        encodedRoute: 'not a route',
        persistedBounds: null,
      ),
      isNull,
    );
  });

  test('in-memory Journey points preserve the complete recorded route', () {
    const points = [
      LatLng(-37.8136, 144.9631),
      LatLng(-37.8127, 144.9659),
      LatLng(-37.8121, 144.9674),
      LatLng(-37.8118, 144.9690),
    ];

    final route = ActivityRoute.fromPoints(points);

    expect(route, isNotNull);
    expect(route!.points, points);
    expect(route.start, points.first);
    expect(route.finish, points.last);
    expect(route.bounds.southwest.latitude, lessThanOrEqualTo(-37.8136));
    expect(route.bounds.northeast.longitude, greaterThanOrEqualTo(144.9690));
  });
}

final _encodedRoute = PolylineCodec.encode(const [
  LatLng(-37.8136, 144.9631),
  LatLng(-37.8127, 144.9659),
  LatLng(-37.8118, 144.9690),
]);
