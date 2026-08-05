/*
 * Author: GitHub Copilot
 * Last Modified: 30/07/2026
 * Description:
 *   Bottom sheet for reviewing and editing journey details before saving.
 *   Allows user to edit start/end location names and view journey stats.
 */

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../domain/journey_location.dart';
import '../domain/transport_mode.dart';
import 'custom_location_form_sheet.dart';

/// Result returned when the journey summary sheet is completed.
enum JourneySummaryResult {
  /// User saved the journey.
  save,

  /// User discarded the journey.
  discard,
}

/// Bottom sheet for reviewing and editing journey before saving.
class JourneySummarySheet extends StatefulWidget {
  const JourneySummarySheet({
    super.key,
    required this.startLocation,
    required this.endLocation,
    required this.transportMode,
    required this.distanceMeters,
    required this.duration,
    required this.routePoints,
    this.xpEarned,
    this.tilesUnlocked = 0,
    required this.onUpdateStartName,
    required this.onUpdateEndName,
    this.userId,
    this.onUpdateStartLocation,
    this.onUpdateEndLocation,
  });

  final JourneyLocation startLocation;
  final JourneyLocation endLocation;
  final TransportMode transportMode;
  final double distanceMeters;
  final Duration duration;
  final List<LatLng> routePoints;
  final int? xpEarned;
  final int tilesUnlocked;
  final ValueChanged<String> onUpdateStartName;
  final ValueChanged<String> onUpdateEndName;
  final String? userId;
  final ValueChanged<JourneyLocation>? onUpdateStartLocation;
  final ValueChanged<JourneyLocation>? onUpdateEndLocation;

  /// Shows the journey summary sheet as a modal bottom sheet.
  static Future<JourneySummaryResult?> show({
    required BuildContext context,
    required JourneyLocation startLocation,
    required JourneyLocation endLocation,
    required TransportMode transportMode,
    required double distanceMeters,
    required Duration duration,
    required List<LatLng> routePoints,
    int? xpEarned,
    int tilesUnlocked = 0,
    required ValueChanged<String> onUpdateStartName,
    required ValueChanged<String> onUpdateEndName,
    String? userId,
    ValueChanged<JourneyLocation>? onUpdateStartLocation,
    ValueChanged<JourneyLocation>? onUpdateEndLocation,
  }) {
    return showModalBottomSheet<JourneySummaryResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => JourneySummarySheet(
        startLocation: startLocation,
        endLocation: endLocation,
        transportMode: transportMode,
        distanceMeters: distanceMeters,
        duration: duration,
        routePoints: routePoints,
        xpEarned: xpEarned,
        tilesUnlocked: tilesUnlocked,
        onUpdateStartName: onUpdateStartName,
        onUpdateEndName: onUpdateEndName,
        userId: userId,
        onUpdateStartLocation: onUpdateStartLocation,
        onUpdateEndLocation: onUpdateEndLocation,
      ),
    );
  }

  @override
  State<JourneySummarySheet> createState() => _JourneySummarySheetState();
}

class _JourneySummarySheetState extends State<JourneySummarySheet> {
  late TextEditingController _startNameController;
  late TextEditingController _endNameController;
  bool _isEditingStart = false;
  bool _isEditingEnd = false;
  late JourneyLocation _startLocation;
  late JourneyLocation _endLocation;

  @override
  void initState() {
    super.initState();
    _startLocation = widget.startLocation;
    _endLocation = widget.endLocation;
    _startNameController = TextEditingController(
      text: widget.startLocation.customName ?? widget.startLocation.displayName,
    );
    _endNameController = TextEditingController(
      text: widget.endLocation.customName ?? widget.endLocation.displayName,
    );
  }

  @override
  void dispose() {
    _startNameController.dispose();
    _endNameController.dispose();
    super.dispose();
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

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '$minutes min${minutes != 1 ? 's' : ''}';
  }

  void _saveStartName() {
    widget.onUpdateStartName(_startNameController.text);
    setState(() {
      _startLocation = _startLocation.copyWith(
        customName: _startNameController.text,
      );
      _isEditingStart = false;
    });
  }

  void _saveEndName() {
    widget.onUpdateEndName(_endNameController.text);
    setState(() {
      _endLocation = _endLocation.copyWith(customName: _endNameController.text);
      _isEditingEnd = false;
    });
  }

  Future<void> _editCustomLocation(bool isStart) async {
    final userId = widget.userId;
    if (userId == null) return;
    final current = isStart ? _startLocation : _endLocation;
    final updated = await CustomLocationFormSheet.show(
      context: context,
      location: current,
      userId: userId,
    );
    if (updated == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startLocation = updated;
        _startNameController.text = updated.name;
      } else {
        _endLocation = updated;
        _endNameController.text = updated.name;
      }
    });
    if (isStart) {
      widget.onUpdateStartLocation?.call(updated);
    } else {
      widget.onUpdateEndLocation?.call(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      key: const ValueKey('journey_summary_keyboard_padding'),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        decoration: BoxDecoration(
          color: AppSurfaces.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
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

                // Title with XP badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Journey Complete!',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppSurfaces.textPrimary(context),
                        ),
                      ),
                    ),
                    if (widget.xpEarned != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.sage.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: AppColors.sage,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '+${widget.xpEarned} XP total',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.sage,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // Stats Row
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
                      Expanded(
                        child: _buildStatItem(
                          context,
                          icon: Icons.straighten,
                          value: _formattedDistance,
                          label: 'Distance',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppSurfaces.border(context),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          context,
                          icon: Icons.timer_outlined,
                          value: _formattedDuration,
                          label: 'Duration',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppSurfaces.border(context),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          context,
                          icon: widget.transportMode.icon,
                          value: widget.transportMode.displayName,
                          label: 'Mode',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppSurfaces.border(context),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          context,
                          icon: Icons.grid_view_rounded,
                          value: '${widget.tilesUnlocked}',
                          label: 'Tiles',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Editable Location Names
                Text(
                  'Journey Details',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppSurfaces.textMuted(context),
                  ),
                ),

                const SizedBox(height: 12),

                // Start Location (Editable)
                _buildEditableLocationField(
                  context,
                  label: 'From',
                  controller: _startNameController,
                  isEditing: _isEditingStart,
                  onEditTap: () => setState(() => _isEditingStart = true),
                  onSaveTap: _saveStartName,
                  icon: Icons.trip_origin,
                ),
                if (_startLocation.placeId == null && widget.userId != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _editCustomLocation(true),
                      icon: const Icon(Icons.notes_outlined, size: 18),
                      label: const Text('Add description & media'),
                    ),
                  ),

                const SizedBox(height: 12),

                // End Location (Editable)
                _buildEditableLocationField(
                  context,
                  label: 'To',
                  controller: _endNameController,
                  isEditing: _isEditingEnd,
                  onEditTap: () => setState(() => _isEditingEnd = true),
                  onSaveTap: _saveEndName,
                  icon: Icons.location_on,
                ),
                if (_endLocation.placeId == null && widget.userId != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _editCustomLocation(false),
                      icon: const Icon(Icons.notes_outlined, size: 18),
                      label: const Text('Add description & media'),
                    ),
                  ),

                const SizedBox(height: 32),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(JourneySummaryResult.discard),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppSurfaces.border(context)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Discard',
                          style: TextStyle(
                            color: AppSurfaces.textMuted(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(JourneySummaryResult.save),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save Journey'),
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
              ],
            ),
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

  Widget _buildEditableLocationField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onEditTap,
    required VoidCallback onSaveTap,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppSurfaces.softCard(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppSurfaces.border(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.sage.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.sage, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppSurfaces.textMuted(context),
                  ),
                ),
                if (isEditing)
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppSurfaces.textPrimary(context),
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => onSaveTap(),
                  )
                else
                  Text(
                    controller.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppSurfaces.textPrimary(context),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: isEditing ? onSaveTap : onEditTap,
            icon: Icon(
              isEditing ? Icons.check : Icons.edit_outlined,
              size: 20,
              color: AppColors.sage,
            ),
          ),
        ],
      ),
    );
  }
}
