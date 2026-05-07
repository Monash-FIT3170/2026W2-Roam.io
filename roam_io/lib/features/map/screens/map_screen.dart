/*
 * Author: Rushil Patel
 * Last Modified: 27/04/2026
 * Description:
 *   Hosts the map screen and connects map rendering callbacks to map state
 *   management.
 */

import 'package:flutter/material.dart';
import '../data/map_controller.dart';
import '../widgets/map_render.dart';

/// Screen that displays the interactive map experience.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapPageState();
}

class _MapPageState extends State<MapScreen> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();

    _mapController = MapController();
    _mapController.addListener(_onMapStateChanged);
    // Initialisation starts location and region loading after the controller is ready.
    _mapController.initialise();
  }

  void _onMapStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _mapController.removeListener(_onMapStateChanged);
    _mapController.disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapRender(
            initialCenter: _mapController.center,
            polygons: _mapController.polygons,
            myLocationEnabled: _mapController.myLocationEnabled,
            onMapCreated: _mapController.onMapCreated,
            onCameraIdle: _mapController.loadViewportRegions,
          ),
        ],
      ),
    );
  }
}
