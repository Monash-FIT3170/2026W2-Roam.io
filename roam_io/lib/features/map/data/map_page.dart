/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Hosts the map screen and wires widget lifecycle to the map controller. This
 *   file keeps UI thin while controller setup, visit XP wiring, and cleanup run
 *   in the correct Flutter lifecycle hooks.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../widgets/map_render.dart';
import 'map_controller.dart';
import 'place_details_sheet.dart';
import 'place_of_interest.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();

    // Own the controller for this page and start its setup work once mounted.
    _mapController = MapController();
    _mapController.addListener(_onMapStateChanged);
    _mapController.onPlaceSelected = _showPlaceDetails;

    // Get user ID from auth provider and initialize
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      _mapController.initialise(
        userId: authProvider.currentUser?.uid,
        onVisitXpAwarded: (xp) => authProvider.addXp(xp),
      );
    });
  }

  void _onMapStateChanged() {
    // Rebuild when the controller publishes new map state.
    if (mounted) setState(() {});
  }

  void _showPlaceDetails(PlaceOfInterest place) {
    PlaceDetailsSheet.show(
      context: context,
      scaffoldMessenger: ScaffoldMessenger.of(context),
      place: place,
      mapController: _mapController,
    );
  }

  @override
  void dispose() {
    // Detach listeners and release controller resources when leaving the page.
    _mapController.onPlaceSelected = null;
    _mapController.removeListener(_onMapStateChanged);
    _mapController.disposeController();
    super.dispose();
  }

  // Build the map page UI from the controller's current state. The controller
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapRender(
            initialCenter: _mapController.center,
            polygons: _mapController.polygons,
            mapStyle: _mapController.mapStyle,
            markers: _mapController.markers,
            myLocationEnabled: _mapController.myLocationEnabled,
            onMapCreated: _mapController.onMapCreated,
            // Load or refresh visible regions after the user stops moving the map.
            onCameraIdle: _mapController.loadViewportRegions,
            onCameraMove: _mapController.onCameraMove,
          ),
        ],
      ),
    );
  }
}
