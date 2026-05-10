/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 9/05/2026
 * Description:
 *   Regression tests for map dark mode styling applied to the Google Map
 *   surface.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/map/domain/map_styles.dart';
import 'package:roam_io/features/map/widgets/map_render.dart';

void main() {
  testWidgets('dark theme applies dark Google Map style', (tester) async {
    await _pumpMapRender(tester, theme: ThemeData.dark());

    final map = _googleMap(tester);

    expect(map.style, MapStyles.dark);
    expect(map.mapToolbarEnabled, isFalse);
    expect(map.zoomControlsEnabled, isFalse);
    expect(map.onMapCreated, isNotNull);
    expect(map.onCameraIdle, isNotNull);
  });

  testWidgets('light theme clears custom Google Map style', (tester) async {
    await _pumpMapRender(tester, theme: ThemeData.light());

    expect(_googleMap(tester).style, isNull);
  });

  testWidgets('theme change updates Google Map style', (tester) async {
    await _pumpMapRender(tester, theme: ThemeData.light());
    expect(_googleMap(tester).style, isNull);

    await _pumpMapRender(tester, theme: ThemeData.dark());
    expect(_googleMap(tester).style, MapStyles.dark);
  });
}

Future<void> _pumpMapRender(
  WidgetTester tester, {
  required ThemeData theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: MapRender(
          initialCenter: const LatLng(-37.8136, 144.9631),
          polygons: const <Polygon>{},
          onMapCreated: (_) async {},
          onCameraIdle: () {},
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

GoogleMap _googleMap(WidgetTester tester) {
  return tester.widget<GoogleMap>(find.byType(GoogleMap));
}
