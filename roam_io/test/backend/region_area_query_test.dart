/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Tests backend region queries expose square-metre polygon area for XP.
 */

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('region API area query', () {
    test('Firebase function returns square-metre polygon area', () {
      final source = File('functions/index.js').readAsStringSync();

      _expectRegionEndpointsSelectArea(source);
    });

    test('local spatial API returns square-metre polygon area', () {
      final source = File('spatial-api/index.js').readAsStringSync();

      _expectRegionEndpointsSelectArea(source);
    });
  });
}

const String _areaSelect = 'ST_Area(geography(geometry)) AS area_square_metres';

void _expectRegionEndpointsSelectArea(String source) {
  final containingRouteStart = source.indexOf("app.post('/region/contains'");
  final viewportRouteStart = source.indexOf("app.post('/regions/viewport'");

  expect(containingRouteStart, isNonNegative);
  expect(viewportRouteStart, isNonNegative);

  final containingRoute = source.substring(
    containingRouteStart,
    viewportRouteStart,
  );
  final viewportRoute = source.substring(viewportRouteStart);

  // Both region endpoints must expose the exact PostGIS area alias consumed by
  // RegionPolygon.fromJson; otherwise valid unlocks fall back to 25 XP.
  expect(containingRoute, contains(_areaSelect));
  expect(viewportRoute, contains(_areaSelect));
  expect(RegExp(RegExp.escape(_areaSelect)).allMatches(source), hasLength(2));
}
