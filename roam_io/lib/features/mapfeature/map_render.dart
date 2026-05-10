// Renders the Google Map widget from prepared controller state and callbacks.
// This keeps map presentation separate from business logic and data loading.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapRender extends StatelessWidget {

  static double defaultZoom = 13.5;

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
      initialCameraPosition: CameraPosition(
        target: initialCenter,
        zoom: defaultZoom,
      ),
      style: mapStyle,
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
