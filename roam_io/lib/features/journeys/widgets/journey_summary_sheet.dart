/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 21 August 2026
 * Description:
 *   Page for reviewing completed Journey metrics, route media, and activity
 *   title before saving or discarding the resulting activity.
 */

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../shared/widgets/app_page_transition.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
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
  const JourneySummaryResult({required this.action, required this.title});

  final JourneySummaryAction action;
  final String title;
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
  final DateTime? startTime;
  final String? initialTitle;
  final int? xpEarned;
  final int tilesUnlocked;
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
                _JourneyRoutePreview(routePoints: widget.routePoints),

                const SizedBox(height: 24),

                Text(
                  'Media',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppSurfaces.textMuted(context),
                  ),
                ),
                const SizedBox(height: 12),
                _buildMediaPlaceholder(context),

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

  Widget _buildMediaPlaceholder(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppSurfaces.softCard(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppSurfaces.border(context)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            color: AppSurfaces.textMuted(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Add media coming soon',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppSurfaces.textMuted(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
}

class _JourneyRoutePreview extends StatelessWidget {
  const _JourneyRoutePreview({required this.routePoints});

  final List<LatLng> routePoints;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppSurfaces.softCard(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppSurfaces.border(context)),
        ),
        child: CustomPaint(
          painter: _JourneyRoutePreviewPainter(
            points: routePoints,
            routeColor: AppColors.sage,
            mutedColor: AppSurfaces.textSubtle(context),
          ),
          child: Center(
            child: routePoints.length < 2
                ? Text(
                    'Route recorded',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppSurfaces.textMuted(context),
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _JourneyRoutePreviewPainter extends CustomPainter {
  const _JourneyRoutePreviewPainter({
    required this.points,
    required this.routeColor,
    required this.mutedColor,
  });

  final List<LatLng> points;
  final Color routeColor;
  final Color mutedColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      final paint = Paint()
        ..color = mutedColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(12),
        ).deflate(18),
        paint,
      );
      return;
    }

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    const padding = 20.0;
    final drawSize = Size(
      (size.width - padding * 2).clamp(1, double.infinity).toDouble(),
      (size.height - padding * 2).clamp(1, double.infinity).toDouble(),
    );
    final latSpan = (maxLat - minLat).abs();
    final lngSpan = (maxLng - minLng).abs();
    final safeLatSpan = latSpan == 0 ? 0.00001 : latSpan;
    final safeLngSpan = lngSpan == 0 ? 0.00001 : lngSpan;

    Offset mapPoint(LatLng point) {
      final x =
          padding + ((point.longitude - minLng) / safeLngSpan) * drawSize.width;
      final y =
          padding + ((maxLat - point.latitude) / safeLatSpan) * drawSize.height;
      return Offset(x, y);
    }

    final firstPoint = mapPoint(points.first);
    final path = Path()..moveTo(firstPoint.dx, firstPoint.dy);
    for (final point in points.skip(1)) {
      final offset = mapPoint(point);
      path.lineTo(offset.dx, offset.dy);
    }

    final routePaint = Paint()
      ..color = routeColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 5;
    canvas.drawPath(path, routePaint);

    final endpointPaint = Paint()
      ..color = routeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(mapPoint(points.first), 5, endpointPaint);
    canvas.drawCircle(mapPoint(points.last), 5, endpointPaint);
  }

  @override
  bool shouldRepaint(covariant _JourneyRoutePreviewPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.routeColor != routeColor ||
        oldDelegate.mutedColor != mutedColor;
  }
}
