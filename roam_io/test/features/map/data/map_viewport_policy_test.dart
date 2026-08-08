import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/map/data/map_viewport_policy.dart';

void main() {
  test('viewport loading is supported at and above zoom 14.5', () {
    final policy = MapViewportPolicy();

    expect(policy.supportsViewportLoading(14.49), isFalse);
    expect(policy.supportsViewportLoading(14.5), isTrue);
    expect(policy.supportsViewportLoading(16), isTrue);
  });

  test('uses hysteresis when changing map layer modes', () {
    final policy = MapViewportPolicy();

    expect(
      policy.modeForZoom(zoom: 12, currentMode: MapLayerMode.sa1Detail),
      MapLayerMode.sa3Overview,
    );
    expect(
      policy.modeForZoom(zoom: 13, currentMode: MapLayerMode.sa1Detail),
      MapLayerMode.sa1Detail,
    );
    expect(
      policy.modeForZoom(zoom: 14, currentMode: MapLayerMode.sa3Overview),
      MapLayerMode.sa1Detail,
    );
    expect(
      policy.modeForZoom(zoom: 13, currentMode: MapLayerMode.sa3Overview),
      MapLayerMode.sa3Overview,
    );
  });

  test('expands and compares viewport bounds', () {
    final policy = MapViewportPolicy();
    final bounds = LatLngBounds(
      southwest: const LatLng(-38, 144),
      northeast: const LatLng(-37, 145),
    );

    final expanded = policy.expandSa1Bounds(bounds);

    expect(expanded.southwest, const LatLng(-39.25, 142.75));
    expect(expanded.northeast, const LatLng(-35.75, 146.25));
    expect(policy.containsBounds(outer: expanded, inner: bounds), isTrue);
    expect(policy.containsBounds(outer: bounds, inner: expanded), isFalse);
  });
}
