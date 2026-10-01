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
import 'package:roam_io/features/map/domain/exploration_overlay_style.dart';
import 'package:roam_io/features/map/domain/map_styles.dart';
import 'package:roam_io/features/map/data/map_viewport_policy.dart';
import 'package:roam_io/features/map/widgets/map_render.dart';

void main() {
  testWidgets('dark theme applies dark Google Map style', (tester) async {
    await _pumpMapRender(tester, theme: ThemeData.dark());

    final map = _googleMap(tester);

    expect(map.style, MapStyles.dark);
    expect(map.mapToolbarEnabled, isFalse);
    expect(map.zoomControlsEnabled, isFalse);
    expect(map.minMaxZoomPreference.minZoom, MapViewportPolicy.minimumZoom);
    expect(map.myLocationButtonEnabled, isFalse);
    expect(map.onMapCreated, isNotNull);
    expect(map.onCameraIdle, isNotNull);
    expect(map.onCameraMoveStarted, isNotNull);
  });

  testWidgets('light theme applies light Google Map style', (tester) async {
    await _pumpMapRender(tester, theme: ThemeData.light());

    expect(_googleMap(tester).style, MapStyles.light);
  });

  testWidgets('theme change updates Google Map style', (tester) async {
    await _pumpMapRender(tester, theme: ThemeData.light());
    expect(_googleMap(tester).style, MapStyles.light);

    await _pumpMapRender(tester, theme: ThemeData.dark());
    expect(_googleMap(tester).style, MapStyles.dark);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} map keeps translucent polygons and location markers',
      (tester) async {
        final style = ExplorationOverlayStyle.forBrightness(brightness);
        final heatmapPolygon = Polygon(
          polygonId: const PolygonId('heatmap-region'),
          points: const <LatLng>[
            LatLng(-37.81, 144.96),
            LatLng(-37.81, 144.97),
            LatLng(-37.82, 144.97),
          ],
          fillColor: style.heatmapFillColorForIntensity(0.5),
        );
        const marker = Marker(
          markerId: MarkerId('visible-place'),
          position: LatLng(-37.815, 144.965),
        );

        await _pumpMapRender(
          tester,
          theme: brightness == Brightness.dark
              ? ThemeData.dark()
              : ThemeData.light(),
          polygons: <Polygon>{heatmapPolygon},
          markers: <Marker>{marker},
          myLocationEnabled: true,
        );

        final map = _googleMap(tester);
        expect(
          map.style,
          brightness == Brightness.dark ? MapStyles.dark : MapStyles.light,
        );
        expect(map.polygons, contains(heatmapPolygon));
        expect(map.markers, contains(marker));
        expect(map.myLocationEnabled, isTrue);
        expect(
          map.polygons.single.fillColor,
          style.heatmapFillColorForIntensity(0.5),
        );
        expect(map.polygons.single.fillColor.a, lessThan(1));
      },
    );
  }
}

Future<void> _pumpMapRender(
  WidgetTester tester, {
  required ThemeData theme,
  Set<Polygon> polygons = const <Polygon>{},
  Set<Marker> markers = const <Marker>{},
  bool myLocationEnabled = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: MapRender(
          initialCenter: const LatLng(-37.8136, 144.9631),
          polygons: polygons,
          markers: markers,
          myLocationEnabled: myLocationEnabled,
          onMapCreated: (_) async {},
          onCameraIdle: () {},
          onCameraMoveStarted: () {},
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

GoogleMap _googleMap(WidgetTester tester) {
  return tester.widget<GoogleMap>(find.byType(GoogleMap));
}
