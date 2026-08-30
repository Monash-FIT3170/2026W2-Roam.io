/*
 * Author: GitHub Copilot
 * Last Modified: 30/07/2026
 * Description:
 *   Bottom sheet for ending a journey. Shows stats preview and allows
 *   user to select end location before proceeding to summary.
 */

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../domain/journey_location.dart';
import '../domain/nearby_place.dart';
import '../domain/transport_mode.dart';

/// Result returned when the end journey sheet is completed.
class EndJourneyResult {
  const EndJourneyResult({required this.endLocation});

  final JourneyLocation endLocation;
}

/// Bottom sheet for completing a journey and selecting end location.
class EndJourneySheet extends StatefulWidget {
  const EndJourneySheet({
    super.key,
    required this.currentPosition,
    required this.distanceMeters,
    required this.duration,
    required this.transportMode,
    this.nearbyPlaces = const [],
  });

  /// The user's current GPS position.
  final LatLng currentPosition;

  /// Total distance traveled in meters.
  final double distanceMeters;

  /// Total journey duration.
  final Duration duration;

  /// The transport mode used.
  final TransportMode transportMode;

  /// Optional list of nearby places to select from.
  final List<NearbyPlace> nearbyPlaces;

  /// Shows the end journey sheet as a modal bottom sheet.
  static Future<EndJourneyResult?> show({
    required BuildContext context,
    required LatLng currentPosition,
    required double distanceMeters,
    required Duration duration,
    required TransportMode transportMode,
    List<NearbyPlace> nearbyPlaces = const [],
  }) {
    return showModalBottomSheet<EndJourneyResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EndJourneySheet(
        currentPosition: currentPosition,
        distanceMeters: distanceMeters,
        duration: duration,
        transportMode: transportMode,
        nearbyPlaces: nearbyPlaces,
      ),
    );
  }

  @override
  State<EndJourneySheet> createState() => _EndJourneySheetState();
}

class _EndJourneySheetState extends State<EndJourneySheet> {
  JourneyLocation? _selectedLocation;
  bool _useCurrentLocation = true;

  @override
  void initState() {
    super.initState();
    _selectedLocation = JourneyLocation.currentLocation(widget.currentPosition);
  }

  String get _formattedDistance {
    if (widget.distanceMeters >= 1000) {
      return '${(widget.distanceMeters / 1000).toStringAsFixed(2)} km';
    }
    return '${widget.distanceMeters.toInt()} m';
  }

  String get _formattedDuration {
    final hours = widget.duration.inHours;
    final minutes = widget.duration.inMinutes % 60;
    final seconds = widget.duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
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

  void _finishJourney() {
    if (_selectedLocation == null) return;

    Navigator.of(
      context,
    ).pop(EndJourneyResult(endLocation: _selectedLocation!));
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
                'End Journey',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppSurfaces.textPrimary(context),
                ),
              ),

              const SizedBox(height: 16),

              // Journey Stats Preview
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppSurfaces.softCard(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppSurfaces.border(context)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      context,
                      icon: Icons.straighten,
                      value: _formattedDistance,
                      label: 'Distance',
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: AppSurfaces.border(context),
                    ),
                    _buildStatItem(
                      context,
                      icon: Icons.timer_outlined,
                      value: _formattedDuration,
                      label: 'Duration',
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: AppSurfaces.border(context),
                    ),
                    _buildStatItem(
                      context,
                      icon: widget.transportMode.icon,
                      value: widget.transportMode.displayName,
                      label: 'Mode',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // End Location Section
              Text(
                'End Location',
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

              const SizedBox(height: 32),

              // Finish Button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selectedLocation != null ? _finishJourney : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Finish'),
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

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppColors.sage),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppSurfaces.textPrimary(context),
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppSurfaces.textMuted(context),
          ),
        ),
      ],
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
}
