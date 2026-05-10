<<<<<<<< HEAD:roam_io/lib/features/map/widgets/map_render.dart
/*
 * Author: Rushil Patel
 * Last Modified: 27/04/2026
 * Description:
 *   Renders the Google Map surface with location display, polygons, and map
 *   lifecycle callbacks supplied by the controller.
 */
========
// Renders the Google Map widget from prepared controller state and callbacks.
// This keeps map presentation separate from business logic and data loading.
>>>>>>>> feature/ART-4-fog-of-war:roam_io/lib/features/map/data/map_render.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Stateless Google Map wrapper used by the map page.
class MapRender extends StatelessWidget {
<<<<<<<< HEAD:roam_io/lib/features/map/widgets/map_render.dart
========

  static double defaultZoom = 13.5;

>>>>>>>> feature/ART-4-fog-of-war:roam_io/lib/features/map/data/map_render.dart
  const MapRender({
    super.key,
    required this.initialCenter,
    required this.polygons,
    required this.onMapCreated,
    this.mapStyle,
    this.markers = const {},
    this.myLocationEnabled = false,
    this.onCameraIdle,
    this.onCameraMove,
  });

  final LatLng initialCenter;
  final Set<Polygon> polygons;
  final Set<Marker> markers;
  final Future<void> Function(GoogleMapController) onMapCreated;
  final String? mapStyle;
  final bool myLocationEnabled;
  final VoidCallback? onCameraIdle;
  final void Function(CameraPosition)? onCameraMove;

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
<<<<<<<< HEAD:roam_io/lib/features/map/widgets/map_render.dart
      initialCameraPosition: CameraPosition(target: initialCenter, zoom: 13.5),
========
      initialCameraPosition: CameraPosition(
        target: initialCenter,
        zoom: defaultZoom,
      ),
      style: mapStyle,
>>>>>>>> feature/ART-4-fog-of-war:roam_io/lib/features/map/data/map_render.dart
      onMapCreated: onMapCreated,
      polygons: polygons,
      markers: markers,
      myLocationEnabled: myLocationEnabled,
      myLocationButtonEnabled: myLocationEnabled,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      onCameraIdle: onCameraIdle,
      onCameraMove: onCameraMove,
    );
  }
}
