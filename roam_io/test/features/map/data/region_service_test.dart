/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Tests spatial API JSON response parsing for region polygon area values.
 */

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roam_io/features/map/data/region_service.dart';

void main() {
  group('RegionService', () {
    test(
      'parses /region/contains area_square_metres from raw API JSON',
      () async {
        final service = RegionService(
          client: MockClient((request) async {
            expect(request.url.path, endsWith('/region/contains'));
            return http.Response(
              jsonEncode(<String, dynamic>{
                'id': 'region-1',
                'name': 'Region One',
                'area_square_metres': 4000000.0,
                'geometry': _polygonGeometry,
              }),
              200,
            );
          }),
        );

        final region = await service.getContainingRegion(lat: -37, lng: 144);

        expect(region?.areaSquareMetres, 4000000.0);
      },
    );

    test(
      'parses /regions/viewport area_square_metres from raw API JSON',
      () async {
        final service = RegionService(
          client: MockClient((request) async {
            expect(request.url.path, endsWith('/regions/viewport'));
            return http.Response(
              jsonEncode(<Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'region-1',
                  'name': 'Region One',
                  'area_square_metres': '1000000.0',
                  'geometry': _polygonGeometry,
                },
              ]),
              200,
            );
          }),
        );

        final regions = await service.getRegionsForViewport(
          south: -38,
          west: 144,
          north: -37,
          east: 145,
        );

        expect(regions.single.areaSquareMetres, 1000000.0);
      },
    );
  });
}

const Map<String, dynamic> _polygonGeometry = <String, dynamic>{
  'type': 'Polygon',
  'coordinates': <dynamic>[
    <dynamic>[
      <double>[144.0, -37.0],
      <double>[145.0, -37.0],
      <double>[145.0, -38.0],
      <double>[144.0, -38.0],
      <double>[144.0, -37.0],
    ],
  ],
};
