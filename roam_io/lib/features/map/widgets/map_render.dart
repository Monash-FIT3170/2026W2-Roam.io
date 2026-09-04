/*
 * Author: Rushil Patel
 * Last Modified: 27/04/2026
 * Description:
 *   Renders the Google Map surface with location display, polygons, and map
 *   lifecycle callbacks supplied by the controller.
 */

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/map_styles.dart';
import '../data/map_viewport_policy.dart';

/// Stateless Google Map wrapper used by the map page.
class MapRender extends StatelessWidget {
  static double defaultZoom = 16.0;

  const MapRender({
    super.key,
    required this.initialCenter,
    required this.polygons,
    required this.onMapCreated,
    this.markers = const {},
    this.polylines = const {},
    this.myLocationEnabled = false,
    this.onCameraIdle,
    this.onCameraMove,
    this.onCameraMoveStarted,
  });

  final LatLng initialCenter;
  final Set<Polygon> polygons;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final Future<void> Function(GoogleMapController) onMapCreated;
  final bool myLocationEnabled;
  final VoidCallback? onCameraIdle;
  final void Function(CameraPosition)? onCameraMove;
  final VoidCallback? onCameraMoveStarted;

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initialCenter, zoom: 16.0),
      minMaxZoomPreference: const MinMaxZoomPreference(
        MapViewportPolicy.minimumZoom,
        null,
      ),
      style: MapStyles.forBrightness(Theme.of(context).brightness),
      onMapCreated: onMapCreated,
      polygons: polygons,
      markers: markers,
      polylines: polylines,
      myLocationEnabled: myLocationEnabled,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      // The fog overlay reproduces the map's projection in Dart to place cloud
      // geometry. Rotation is one extra canvas.rotate and stays supported, but
      // tilt is a perspective projection whose field of view the plugin does
      // not expose, so a tilted map would slide out of alignment with its fog.
      tiltGesturesEnabled: false,
      onCameraIdle: onCameraIdle,
      onCameraMove: onCameraMove,
      onCameraMoveStarted: onCameraMoveStarted,
    );
  }
}
