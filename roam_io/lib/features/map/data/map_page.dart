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
import '../../../shared/widgets/app_toast.dart';
import '../widgets/map_render.dart';
import 'map_controller.dart';
import 'place_details_sheet.dart';
import 'place_of_interest.dart';
import 'region_polygon.dart';
import 'tile_unlock_xp_service.dart';

/// Map screen that connects controller unlock events to provider XP and toast UI.
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

    final authProvider = context.read<AuthProvider>();

    // Own the controller for this page and start its setup work once mounted.
    _mapController = MapController(
      tileUnlockXpService: TileUnlockXpService(addXp: authProvider.addXp),
    );
    _mapController.addListener(_onMapStateChanged);
    _mapController.onPlaceSelected = _showPlaceDetails;
    _mapController.onRegionUnlockRewarded = _showRegionUnlockReward;

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

  void _showRegionUnlockReward(RegionPolygon region, int xpAwarded) {
    if (!mounted) return;
    AppToast.success(context, 'Unlocked ${region.name} +$xpAwarded XP');
  }

  @override
  void dispose() {
    // Detach listeners and release controller resources when leaving the page.
    _mapController.onPlaceSelected = null;
    _mapController.onRegionUnlockRewarded = null;
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
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            right: 16,
            child: _HeatmapToggleButton(
              isEnabled: _mapController.isHeatmapEnabled,
              onPressed: _mapController.toggleHeatmap,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeatmapToggleButton extends StatelessWidget {
  const _HeatmapToggleButton({
    required this.isEnabled,
    required this.onPressed,
  });

  final bool isEnabled;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = Colors.deepOrange.shade600;
    final inactiveColor = theme.colorScheme.surface;

    return Tooltip(
      message: isEnabled ? 'Hide heatmap' : 'Show heatmap',
      child: Material(
        color: isEnabled ? activeColor : inactiveColor,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.24),
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: () {
            onPressed();
          },
          icon: const Icon(Icons.local_fire_department_rounded),
          color: isEnabled ? Colors.white : theme.colorScheme.onSurface,
          iconSize: 26,
        ),
      ),
    );
  }
}
