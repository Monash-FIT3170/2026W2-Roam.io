import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('region API area query', () {
    test('Firebase function returns square-metre polygon area', () {
      final source = File('functions/index.js').readAsStringSync();

      expect(source, contains(_areaSelect));
    });

    test('local spatial API returns square-metre polygon area', () {
      final source = File('spatial-api/index.js').readAsStringSync();

      expect(source, contains(_areaSelect));
    });
  });
}

const String _areaSelect = 'ST_Area(geography(geometry)) AS area_square_metres';
