/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 22 August 2026
 * Description:
 *   Page for reviewing completed Journey metrics, route media, and activity
 *   title before saving or discarding the resulting activity.
 */

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/widgets/app_page_transition.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../../activity_feed/domain/activity_route.dart';
import '../../activity_feed/models/activity_media_item.dart';
import '../../activity_feed/widgets/activity_map_preview.dart';
import '../../activity_feed/widgets/route_marker_icons.dart';
import '../../map/data/journey_map_snapshot_service.dart';
import '../domain/journey_location.dart';
import '../domain/journey_title_generator.dart';
import '../domain/transport_mode.dart';

/// Action chosen from the journey summary sheet.
enum JourneySummaryAction {
  /// User saved the journey.
  save,

  /// User discarded the journey.
  discard,
}

/// Result returned when the journey summary sheet is completed.
class JourneySummaryResult {
  const JourneySummaryResult({
    required this.action,
    required this.title,
    this.media = const <PendingActivityMedia>[],
    this.mapImageBytes,
  });

  final JourneySummaryAction action;
  final String title;
  final List<PendingActivityMedia> media;

  /// The reviewed route captured off the map above, fog included. Null when the
  /// map had not settled before the user chose an action.
  final Uint8List? mapImageBytes;
}

/// Page for reviewing a completed Journey before saving its activity.
class JourneySummarySheet extends StatefulWidget {
  const JourneySummarySheet({
    super.key,
    required this.startLocation,
    required this.endLocation,
    required this.transportMode,
    required this.distanceMeters,
    required this.duration,
    required this.routePoints,
    this.startTime,
    this.initialTitle,
    this.xpEarned,
    this.tilesUnlocked = 0,
    this.visitedRegionIds = const <String>{},
    this.currentRegionId,
    JourneyMapSnapshotService? mapSnapshotService,
    this.endpointMarkerIcons,
    required this.onUpdateStartName,
    required this.onUpdateEndName,
    this.userId,
    this.onUpdateStartLocation,
    this.onUpdateEndLocation,
  }) : _mapSnapshotService = mapSnapshotService;

  final JourneyLocation startLocation;
  final JourneyLocation endLocation;
  final TransportMode transportMode;
  final double distanceMeters;
  final Duration duration;
  final List<LatLng> routePoints;
  final DateTime? startTime;
  final String? initialTitle;
  final int? xpEarned;
  final int tilesUnlocked;
  final Set<String> visitedRegionIds;
  final String? currentRegionId;
  final JourneyMapSnapshotService? _mapSnapshotService;
  final RouteEndpointMarkerIcons? endpointMarkerIcons;
  final ValueChanged<String> onUpdateStartName;
  final ValueChanged<String> onUpdateEndName;
  final String? userId;
  final ValueChanged<JourneyLocation>? onUpdateStartLocation;
  final ValueChanged<JourneyLocation>? onUpdateEndLocation;

  /// Shows the journey completion page with a horizontal forward transition.
  static Future<JourneySummaryResult?> show({
    required BuildContext context,
    required JourneyLocation startLocation,
    required JourneyLocation endLocation,
    required TransportMode transportMode,
    required double distanceMeters,
    required Duration duration,
    required List<LatLng> routePoints,
    DateTime? startTime,
    String? initialTitle,
    int? xpEarned,
    int tilesUnlocked = 0,
    Set<String> visitedRegionIds = const <String>{},
    String? currentRegionId,
    JourneyMapSnapshotService? mapSnapshotService,
    RouteEndpointMarkerIcons? endpointMarkerIcons,
    required ValueChanged<String> onUpdateStartName,
    required ValueChanged<String> onUpdateEndName,
    String? userId,
    ValueChanged<JourneyLocation>? onUpdateStartLocation,
    ValueChanged<JourneyLocation>? onUpdateEndLocation,
  }) {
    return Navigator.of(context).push<JourneySummaryResult>(
      appHorizontalPageRoute<JourneySummaryResult>(
        settings: const RouteSettings(name: 'journey-complete'),
        builder: (context) => JourneySummarySheet(
          startLocation: startLocation,
          endLocation: endLocation,
          transportMode: transportMode,
          distanceMeters: distanceMeters,
          duration: duration,
          routePoints: routePoints,
          startTime: startTime,
          initialTitle: initialTitle,
          xpEarned: xpEarned,
          tilesUnlocked: tilesUnlocked,
          visitedRegionIds: visitedRegionIds,
          currentRegionId: currentRegionId,
          mapSnapshotService: mapSnapshotService,
          endpointMarkerIcons: endpointMarkerIcons,
          onUpdateStartName: onUpdateStartName,
          onUpdateEndName: onUpdateEndName,
          userId: userId,
          onUpdateStartLocation: onUpdateStartLocation,
          onUpdateEndLocation: onUpdateEndLocation,
        ),
      ),
    );
  }

  @override
  State<JourneySummarySheet> createState() => _JourneySummarySheetState();
}

class _JourneySummarySheetState extends State<JourneySummarySheet> {
  late TextEditingController _titleController;
  late final ActivityRoute? _route;
  final _imagePicker = ImagePicker();
  final _selectedMedia = <PendingActivityMedia>[];
  Uint8List? _mapImageBytes;

  @override
  void initState() {
    super.initState();
    final generatedTitle = generateJourneyTitle(
      widget.startTime ?? DateTime.now(),
    );
    _titleController = TextEditingController(
      text: widget.initialTitle?.trim().isNotEmpty == true
          ? widget.initialTitle!.trim()
          : generatedTitle,
    );
    _route = ActivityRoute.fromPoints(widget.routePoints);
  }

  @override
  void dispose() {
    _titleController.dispose();
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

  JourneySummaryResult _result(JourneySummaryAction action) {
    final title = _titleController.text.trim();
    return JourneySummaryResult(
      action: action,
      title: title.isEmpty
          ? generateJourneyTitle(widget.startTime ?? DateTime.now())
          : title,
      media: List<PendingActivityMedia>.unmodifiable(_selectedMedia),
      mapImageBytes: _mapImageBytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppSurfaces.card(context),
      body: AnimatedPadding(
        key: const ValueKey('journey_summary_keyboard_padding'),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Journey Complete!',
                          maxLines: 1,
                          softWrap: false,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppSurfaces.textPrimary(context),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                        child: Text(
                          '+${widget.xpEarned} XP',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.sage,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                _buildTitleField(context),

                const SizedBox(height: 16),

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

                Text(
                  'Route',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppSurfaces.textMuted(context),
                  ),
                ),
                const SizedBox(height: 12),
                ActivityMapPreview(
                  route: _route,
                  visitedRegionIds: widget.visitedRegionIds,
                  currentRegionId: widget.currentRegionId,
                  mapSnapshotService: widget._mapSnapshotService,
                  transportMode: widget.transportMode,
                  showEndpoints: true,
                  endpointMarkerIcons: widget.endpointMarkerIcons,
                  // This map already frames the whole journey with the fog it
                  // was recorded against, so it is what feed cards get to show
                  // instead of loading tiles per card.
                  onSnapshotCaptured: (bytes) => _mapImageBytes = bytes,
                ),

                const SizedBox(height: 24),

                Text(
                  'Media',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppSurfaces.textMuted(context),
                  ),
                ),
                const SizedBox(height: 12),
                _buildMediaPicker(context),

                const SizedBox(height: 32),

                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(_result(JourneySummaryAction.discard)),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.cream,
                          foregroundColor: AppSurfaces.textMuted(context),
                          side: BorderSide(color: AppSurfaces.border(context)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Discard',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(_result(JourneySummaryAction.save)),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save Activity'),
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

  Widget _buildTitleField(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: _titleController,
      textInputAction: TextInputAction.done,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: AppSurfaces.textPrimary(context),
      ),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.edit_note_rounded),
        filled: true,
        fillColor: AppSurfaces.softCard(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppSurfaces.border(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppSurfaces.border(context)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.sage, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildMediaPicker(BuildContext context) {
    final theme = Theme.of(context);
    final remainingSlots = 3 - _selectedMedia.length;
    final canAddMedia = remainingSlots > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppSurfaces.softCard(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppSurfaces.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Media',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppSurfaces.textPrimary(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${_selectedMedia.length}/3',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppSurfaces.textMuted(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedMedia.isNotEmpty) ...[
            SizedBox(
              height: 106,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                itemCount: _selectedMedia.length,
                // ignore: deprecated_member_use
                onReorder: _reorderMedia,
                proxyDecorator: (child, _, animation) {
                  return ScaleTransition(
                    scale: Tween<double>(begin: 1, end: 1.04).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    child: child,
                  );
                },
                itemBuilder: (context, index) => Padding(
                  key: ValueKey<String>(
                    'pending-media-${_selectedMedia[index].file.path}',
                  ),
                  padding: EdgeInsets.only(
                    right: index == _selectedMedia.length - 1 ? 0 : 10,
                  ),
                  child: ReorderableDragStartListener(
                    index: index,
                    child: _PendingMediaTile(
                      media: _selectedMedia[index],
                      onRemove: () => _removeMedia(index),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_selectedMedia.isEmpty)
            _PhotoLibraryTile(enabled: canAddMedia, onTap: _chooseFromLibrary)
          else
            OutlinedButton.icon(
              onPressed: canAddMedia ? _chooseFromLibrary : null,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Photo Library'),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  canAddMedia ? 'Add photos or videos' : 'Media limit reached',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppSurfaces.textMuted(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Take photo',
                onPressed: canAddMedia ? _takePhoto : null,
                icon: const Icon(Icons.photo_camera_outlined),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: 'Record video',
                onPressed: canAddMedia ? _takeVideo : null,
                icon: const Icon(Icons.videocam_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _chooseFromLibrary() async {
    final remainingSlots = 3 - _selectedMedia.length;
    if (remainingSlots <= 0) return;

    final picked = remainingSlots == 1
        ? [
            if (await _imagePicker.pickMedia(
                  maxWidth: 1920,
                  maxHeight: 1920,
                  imageQuality: 85,
                )
                case final XFile file)
              file,
          ]
        : await _imagePicker.pickMultipleMedia(
            maxWidth: 1920,
            maxHeight: 1920,
            imageQuality: 85,
            limit: remainingSlots,
          );
    _addPickedMedia(picked);
  }

  Future<void> _takePhoto() async {
    if (_selectedMedia.length >= 3) return;
    final file = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (file != null) {
      _addPickedMedia([file], explicitType: ActivityMediaType.photo);
    }
  }

  Future<void> _takeVideo() async {
    if (_selectedMedia.length >= 3) return;
    final file = await _imagePicker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 2),
    );
    if (file != null) {
      _addPickedMedia([file], explicitType: ActivityMediaType.video);
    }
  }

  void _addPickedMedia(List<XFile> files, {ActivityMediaType? explicitType}) {
    if (files.isEmpty || !mounted) return;
    final remainingSlots = 3 - _selectedMedia.length;
    if (remainingSlots <= 0) return;
    final accepted = files.take(remainingSlots).toList(growable: false);
    setState(() {
      _selectedMedia.addAll(
        accepted.map(
          (file) => PendingActivityMedia(
            file: file,
            type: explicitType ?? _inferMediaType(file),
          ),
        ),
      );
    });
    if (files.length > accepted.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can add up to 3 media items.')),
      );
    }
  }

  ActivityMediaType _inferMediaType(XFile file) {
    final mimeType = file.mimeType?.toLowerCase();
    if (mimeType?.startsWith('video/') == true) {
      return ActivityMediaType.video;
    }
    final name = file.name.toLowerCase();
    if (name.endsWith('.mp4') ||
        name.endsWith('.mov') ||
        name.endsWith('.m4v') ||
        name.endsWith('.avi') ||
        name.endsWith('.webm')) {
      return ActivityMediaType.video;
    }
    return ActivityMediaType.photo;
  }

  void _removeMedia(int index) {
    setState(() => _selectedMedia.removeAt(index));
  }

  void _reorderMedia(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final item = _selectedMedia.removeAt(oldIndex);
      _selectedMedia.insert(newIndex, item);
    });
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
}

class _PendingMediaTile extends StatelessWidget {
  const _PendingMediaTile({required this.media, required this.onRemove});

  final PendingActivityMedia media;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppSurfaces.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppSurfaces.border(context)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: media.isVideo
                    ? const Center(child: Icon(Icons.play_circle_outline))
                    : Image.file(File(media.file.path), fit: BoxFit.cover),
              ),
            ),
            if (media.isVideo)
              const Positioned(
                left: 8,
                bottom: 8,
                child: Icon(Icons.videocam, color: Colors.white),
              ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoLibraryTile extends StatelessWidget {
  const _PhotoLibraryTile({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppSurfaces.card(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppSurfaces.border(context)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 34,
                color: enabled
                    ? AppColors.sage
                    : AppSurfaces.textMuted(context),
              ),
              const SizedBox(height: 10),
              Text(
                'Photo Library',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppSurfaces.textPrimary(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Add photos or videos',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppSurfaces.textMuted(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
