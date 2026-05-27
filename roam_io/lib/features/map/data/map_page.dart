/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 17/05/2026
 * Description:
 *   Hosts the map screen and wires widget lifecycle to the map controller. This
 *   file keeps UI thin while controller setup, visit XP wiring, heatmap
 *   toggling, place detail display, unlock reward feedback, and cleanup run in
 *   the correct Flutter lifecycle hooks.
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
    _mapController.onRegionUnlockCelebrationRewarded = _showRegionUnlockReward;

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

    final message = 'Unlocked New Region +$xpAwarded XP';
    final auth = context.read<AuthProvider>();

    // When XP triggers a level-up, show the unlock toast inside the celebration
    // overlay (below the centered content) instead of as a scaffold snackbar.
    if (auth.pendingLevelUp != null) {
      auth.stageUnlockToast(message);
      return;
    }

    AppToast.success(context, message);
  }

  @override
  void dispose() {
    // Detach listeners and release controller resources when leaving the page.
    _mapController.onPlaceSelected = null;
    _mapController.onRegionUnlockRewarded = null;
    _mapController.onRegionUnlockCelebrationRewarded = null;
    _mapController.removeListener(_onMapStateChanged);
    _mapController.disposeController();
    super.dispose();
  }

  // Build the map page UI from the controller's current state. The controller
  // uses the shell [Scaffold] only — a nested scaffold here duplicates snackbars.
  @override
  Widget build(BuildContext context) {
    return Stack(
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
        if (_mapController.isHeatmapEnabled)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            left: 16,
            child: _HeatmapLegend(),
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
    );
  }
}

class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.94),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Heatmap legend',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _LegendRow(color: const Color(0xFFFFF176), label: '1–2 entries'),
            const SizedBox(height: 6),
            _LegendRow(color: const Color(0xFFFFC247), label: '3–4 entries'),
            const SizedBox(height: 6),
            _LegendRow(color: const Color(0xFFE53935), label: '5+ entries'),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.14),
              width: 0.8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
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
