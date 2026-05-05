/*
 * Author: [Insert Name Here]
 * Last Modified: 6/05/2026
 * Description:
 *   Renders the Google Map surface with location display, polygons, and map
 *   lifecycle callbacks supplied by the controller.
 */

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Stateless Google Map wrapper used by the map page.
class MapRender extends StatelessWidget {
  const MapRender({
    super.key,
    required this.initialCenter,
    required this.polygons,
    required this.onMapCreated,
    this.myLocationEnabled = false,
    this.onCameraIdle,
  });

  final LatLng initialCenter;
  final Set<Polygon> polygons;
  final Future<void> Function(GoogleMapController) onMapCreated;
  final bool myLocationEnabled;
  final VoidCallback? onCameraIdle;

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initialCenter, zoom: 13.5),
      onMapCreated: onMapCreated,
      polygons: polygons,
      myLocationEnabled: myLocationEnabled,
      myLocationButtonEnabled: myLocationEnabled,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      onCameraIdle: onCameraIdle,
    );
  }
}
