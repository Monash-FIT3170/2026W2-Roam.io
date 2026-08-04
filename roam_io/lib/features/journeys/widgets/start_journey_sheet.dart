/*
 * Author: GitHub Copilot
 * Last Modified: 30/07/2026
 * Description:
 *   Bottom sheet for setting up a new journey. Allows user to select
 *   start location and transport mode before beginning tracking.
 */

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../domain/journey_location.dart';
import '../domain/nearby_place.dart';
import '../domain/transport_mode.dart';

/// Result returned when the start journey sheet is completed.
class StartJourneyResult {
  const StartJourneyResult({
    required this.startLocation,
    required this.transportMode,
  });

  final JourneyLocation startLocation;
  final TransportMode transportMode;
}

/// Bottom sheet for configuring journey start parameters.
class StartJourneySheet extends StatefulWidget {
  const StartJourneySheet({
    super.key,
    required this.currentPosition,
    this.nearbyPlaces = const [],
  });

  /// The user's current GPS position.
  final LatLng currentPosition;

  /// Optional list of nearby places to select from.
  final List<NearbyPlace> nearbyPlaces;

  /// Shows the start journey sheet as a modal bottom sheet.
  static Future<StartJourneyResult?> show({
    required BuildContext context,
    required LatLng currentPosition,
    List<NearbyPlace> nearbyPlaces = const [],
  }) {
    return showModalBottomSheet<StartJourneyResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StartJourneySheet(
        currentPosition: currentPosition,
        nearbyPlaces: nearbyPlaces,
      ),
    );
  }

  @override
  State<StartJourneySheet> createState() => _StartJourneySheetState();
}

class _StartJourneySheetState extends State<StartJourneySheet> {
  TransportMode _selectedMode = TransportMode.walk;
  JourneyLocation? _selectedLocation;
  bool _useCurrentLocation = true;

  @override
  void initState() {
    super.initState();
    _selectedLocation = JourneyLocation.currentLocation(widget.currentPosition);
  }

  void _selectLocation(JourneyLocation location) {
    setState(() {
      _selectedLocation = location;
      _useCurrentLocation = false;
    });
  }

  void _selectCurrentLocation() {
    setState(() {
      _selectedLocation = JourneyLocation.currentLocation(
        widget.currentPosition,
      );
      _useCurrentLocation = true;
    });
  }

  void _startJourney() {
    if (_selectedLocation == null) return;

    Navigator.of(context).pop(
      StartJourneyResult(
        startLocation: _selectedLocation!,
        transportMode: _selectedMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppSurfaces.textSubtle(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Title
              Text(
                'Start Journey',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppSurfaces.textPrimary(context),
                ),
              ),

              const SizedBox(height: 24),

              // Start Location Section
              Text(
                'Start Location',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppSurfaces.textMuted(context),
                ),
              ),

              const SizedBox(height: 12),

              // Current Location Option
              _buildLocationOption(
                context,
                icon: Icons.my_location,
                title: 'Current Location',
                subtitle: 'Use your GPS position',
                isSelected: _useCurrentLocation,
                onTap: _selectCurrentLocation,
              ),

              // Nearby Places
              if (widget.nearbyPlaces.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Nearby',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppSurfaces.textSubtle(context),
                  ),
                ),
                const SizedBox(height: 8),
                ...widget.nearbyPlaces.take(3).map((place) {
                  final isSelected =
                      !_useCurrentLocation &&
                      _selectedLocation?.placeId == place.placeId &&
                      _selectedLocation?.latLng == place.latLng;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildLocationOption(
                      context,
                      icon: place.isCustomLocation
                          ? Icons.circle
                          : Icons.place_outlined,
                      iconColor: place.isCustomLocation ? Colors.black : null,
                      title: place.name,
                      subtitle: place.isCustomLocation
                          ? 'Saved Location'
                          : place.address,
                      isSelected: isSelected,
                      onTap: () => _selectLocation(
                        JourneyLocation(
                          latLng: place.latLng,
                          placeId: place.placeId,
                          displayName: place.name,
                        ),
                      ),
                    ),
                  );
                }),
              ],

              const SizedBox(height: 24),

              // Transport Mode Section
              Text(
                'Transport Mode',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppSurfaces.textMuted(context),
                ),
              ),

              const SizedBox(height: 12),

              // Transport Mode Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TransportMode.journeyOptions.map((mode) {
                  final isSelected = _selectedMode == mode;
                  return _buildModeChip(context, mode, isSelected);
                }).toList(),
              ),

              const SizedBox(height: 32),

              // Start Button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selectedLocation != null ? _startJourney : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Journey'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.sage,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationOption(
    BuildContext context, {
    required IconData icon,
    Color? iconColor,
    required String title,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.sage.withValues(alpha: 0.1)
              : AppSurfaces.softCard(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.sage : AppSurfaces.border(context),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.sage.withValues(alpha: 0.2)
                    : AppSurfaces.innerCard(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color:
                    iconColor ??
                    (isSelected
                        ? AppColors.sage
                        : AppSurfaces.textMuted(context)),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppSurfaces.textPrimary(context),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppSurfaces.textMuted(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.sage, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip(
    BuildContext context,
    TransportMode mode,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.sage : AppSurfaces.softCard(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.sage : AppSurfaces.border(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              mode.icon,
              size: 18,
              color: isSelected ? Colors.white : AppSurfaces.textMuted(context),
            ),
            const SizedBox(width: 6),
            Text(
              mode.displayName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : AppSurfaces.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
