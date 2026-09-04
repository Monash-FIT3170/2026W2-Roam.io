/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 29 August 2026 — Sanjevan Rajasegar
 * Description:
 *   Shared profile dashboard presentation for the authenticated You profile
 *   and selected external public profiles. Detailed analytics can be hidden
 *   for the personal You overview while remaining visible on external profiles.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../../activity_feed/models/activity_feed_item.dart';
import '../../activity_feed/screens/activity_media_gallery_screen.dart';
import '../../map/data/visit.dart';
import '../../map/widgets/media_viewer.dart';
import '../domain/profile_stats.dart';
import '../domain/visited_polygon_record.dart';
import '../domain/xp_event.dart';
import 'profile_identity_header.dart';
import 'profile_metric_pill_selector.dart';

/// Graph metrics shared by personal and external profile dashboards.
enum ProfileGraphMetric {
  locationsVisited,
  tilesUnlocked,
  journeysCompleted,
  sidequestsCompleted,
  xpGained,
}

/// Shared profile body. It does not own identity, auth or relationship state.
class ProfileDashboard extends StatelessWidget {
  const ProfileDashboard({
    super.key,
    required this.displayName,
    required this.username,
    this.photoUrl,
    this.level,
    this.xp,
    this.headerAction,
    required this.stats,
    required this.visits,
    required this.recentVisits,
    required this.tileRecords,
    required this.xpEvents,
    required this.selectedMetric,
    required this.onMetricSelected,
    this.recentVisitsReady = true,
    this.recentVisitsError,
    this.visitsError,
    this.mediaProfileId,
    this.currentUserId,
    this.mediaActivitiesStream,
    this.mediaActivities,
    this.showDetailedAnalytics = true,
    this.trailingChildren = const <Widget>[],
    this.bottomPadding = 24,
  });

  final String displayName;
  final String username;
  final String? photoUrl;
  final int? level;
  final int? xp;
  final Widget? headerAction;
  final ProfileStats stats;
  final List<Visit> visits;
  final List<Visit> recentVisits;
  final List<VisitedPolygonRecord> tileRecords;
  final List<XpEvent> xpEvents;
  final ProfileGraphMetric selectedMetric;
  final ValueChanged<ProfileGraphMetric> onMetricSelected;
  final bool recentVisitsReady;
  final Object? recentVisitsError;
  final Object? visitsError;
  final String? mediaProfileId;
  final String? currentUserId;
  final Stream<List<ActivityFeedItem>>? mediaActivitiesStream;
  final List<ActivityFeedItem>? mediaActivities;
  final bool showDetailedAnalytics;
  final List<Widget> trailingChildren;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ProfileIdentityHeader(
              displayName: displayName,
              username: username,
              photoUrl: photoUrl,
              level: level,
              xp: xp,
              stats: stats.toItems(),
              action: headerAction,
            ),
          ),
          const SizedBox(height: 18),
          if (mediaProfileId != null &&
              mediaProfileId!.isNotEmpty &&
              (mediaActivitiesStream != null || mediaActivities != null)) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ProfileMediaPreviewSection(
                profileId: mediaProfileId!,
                currentUserId: currentUserId,
                activitiesStream: mediaActivitiesStream,
                activities: mediaActivities,
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (showDetailedAnalytics) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ProfileMetricLineGraphSection(
                visits: visits,
                tileRecords: tileRecords,
                xpEvents: xpEvents,
                selectedMetric: selectedMetric,
                onMetricSelected: onMetricSelected,
              ),
            ),
            const SizedBox(height: 20),
            const ProfileSectionTitle(title: 'Most Visited Location'),
            const SizedBox(height: 9),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: visitsError != null
                  ? const _UnavailableActivityCard(
                      message:
                          'Most visited location is unavailable right now.',
                    )
                  : MostVisitedLocationBubble(visits: visits),
            ),
            const SizedBox(height: 16),
            const ProfileSectionTitle(title: 'Recent Visited Locations'),
            const SizedBox(height: 9),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: RecentVisitedLocationsPanel(
                visits: recentVisits,
                isLoading: !recentVisitsReady,
                error: recentVisitsError,
              ),
            ),
          ],
          if (trailingChildren.isNotEmpty) ...[
            const SizedBox(height: 20),
            ...trailingChildren,
          ],
        ],
      ),
    );
  }
}

/// Shared metric selector and line chart used by profile dashboards.
class ProfileMetricLineGraphSection extends StatefulWidget {
  const ProfileMetricLineGraphSection({
    super.key,
    required this.visits,
    required this.tileRecords,
    required this.xpEvents,
    required this.selectedMetric,
    required this.onMetricSelected,
  });

  final List<Visit> visits;
  final List<VisitedPolygonRecord> tileRecords;
  final List<XpEvent> xpEvents;
  final ProfileGraphMetric selectedMetric;
  final ValueChanged<ProfileGraphMetric> onMetricSelected;

  @override
  State<ProfileMetricLineGraphSection> createState() =>
      _ProfileMetricLineGraphSectionState();
}

class _ProfileMetricLineGraphSectionState
    extends State<ProfileMetricLineGraphSection> {
  int? _selectedPointIndex;

  @override
  void didUpdateWidget(covariant ProfileMetricLineGraphSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMetric != widget.selectedMetric) {
      _selectedPointIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buckets = _bucketsForMetric(widget.selectedMetric);
    final hasData = buckets.any((bucket) => bucket.value > 0);
    final selectedIndex = _selectedPointIndex;
    final selectedBucket =
        selectedIndex != null &&
            selectedIndex >= 0 &&
            selectedIndex < buckets.length
        ? buckets[selectedIndex]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileMetricPillSelector(
          labels: ProfileGraphMetric.values
              .map((metric) => metric.label)
              .toList(growable: false),
          itemKeys: ProfileGraphMetric.values
              .map((metric) => 'profile-metric-${metric.name}')
              .toList(growable: false),
          selectedIndex: ProfileGraphMetric.values.indexOf(
            widget.selectedMetric,
          ),
          keyPrefix: 'profile-metric',
          onSelected: (index) =>
              widget.onMetricSelected(ProfileGraphMetric.values[index]),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 24,
          child: selectedBucket == null
              ? const SizedBox.shrink()
              : Align(
                  alignment: Alignment.center,
                  child: Text(
                    selectedBucket.detailLabel(widget.selectedMetric),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppSurfaces.textPrimary(context),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
        ),
        SizedBox(
          height: 198,
          width: double.infinity,
          child: hasData
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    final chart = _ActivityLineChartPainter(
                      buckets: buckets,
                      selectedIndex: selectedIndex,
                      lineColor: theme.colorScheme.primary,
                      fillColor: theme.colorScheme.primary.withValues(
                        alpha: 0.12,
                      ),
                      gridColor: AppSurfaces.border(context),
                      labelColor: AppSurfaces.textMuted(context),
                      axisLabelColor: AppSurfaces.textMuted(context),
                    );
                    final points = chart.pointOffsets(
                      Size(constraints.maxWidth, constraints.maxHeight),
                    );

                    return Stack(
                      children: [
                        CustomPaint(size: Size.infinite, painter: chart),
                        for (var index = 0; index < points.length; index += 1)
                          Positioned(
                            left: points[index].dx - 22,
                            top: points[index].dy - 22,
                            child: GestureDetector(
                              key: ValueKey<String>('graph-point-$index'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(() {
                                  _selectedPointIndex = index;
                                });
                              },
                              child: const SizedBox(width: 44, height: 44),
                            ),
                          ),
                      ],
                    );
                  },
                )
              : Center(
                  child: Text(
                    widget.selectedMetric.emptyMessage,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppSurfaces.textMuted(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  List<_MetricBucket> _bucketsForMetric(ProfileGraphMetric metric) {
    switch (metric) {
      case ProfileGraphMetric.locationsVisited:
        return _weeklyBucketsFromDates(
          widget.visits.map((visit) => visit.visitedAt).toList(),
        );
      case ProfileGraphMetric.tilesUnlocked:
        return _weeklyBucketsFromDates(
          widget.tileRecords.map((record) => record.visitedAt).toList(),
        );
      case ProfileGraphMetric.journeysCompleted:
      case ProfileGraphMetric.sidequestsCompleted:
        return _emptyRecentBuckets();
      case ProfileGraphMetric.xpGained:
        if (widget.xpEvents.isEmpty) {
          return _emptyRecentBuckets();
        }
        return _weeklyBucketsFromXpEvents(widget.xpEvents);
    }
  }
}

/// Shared most-visited location card.
class MostVisitedLocationBubble extends StatelessWidget {
  const MostVisitedLocationBubble({super.key, required this.visits});

  final List<Visit> visits;

  @override
  Widget build(BuildContext context) {
    if (visits.isEmpty) {
      return _LocationBubble(
        title: 'No locations yet',
        subtitle: 'Visit places on the map to build this profile.',
        bubbleIcon: Icons.location_off,
        bubbleColor: AppColors.sage.withValues(alpha: 0.24),
      );
    }

    final topLocation = _selectMostVisitedLocation(visits);
    return _LocationBubble(
      title: 'Top location',
      subtitle: topLocation.displayName,
      bubbleIcon: Icons.location_on,
      bubbleColor: AppColors.sage,
    );
  }

  Visit _selectMostVisitedLocation(List<Visit> visits) {
    final counts = <int, int>{};

    for (final visit in visits) {
      counts.update(visit.placeId, (count) => count + 1, ifAbsent: () => 1);
    }

    Visit? best;
    var bestCount = 0;
    for (final visit in visits) {
      final count = counts[visit.placeId] ?? 0;
      if (best == null ||
          count > bestCount ||
          (count == bestCount && visit.visitedAt.isAfter(best.visitedAt))) {
        best = visit;
        bestCount = count;
      }
    }

    return best!;
  }
}

class _LocationBubble extends StatelessWidget {
  const _LocationBubble({
    required this.title,
    required this.subtitle,
    required this.bubbleIcon,
    this.bubbleColor = AppColors.sage,
  });

  final String title;
  final String subtitle;
  final IconData bubbleIcon;
  final Color bubbleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppSurfaces.border(context)),
        boxShadow: [
          BoxShadow(
            color: AppSurfaces.shadow(context),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bubbleColor.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: bubbleColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(bubbleIcon, color: Colors.white, size: 17),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppSurfaces.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppSurfaces.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Recent visits panel with reduced text density for profile dashboards.
class RecentVisitedLocationsPanel extends StatelessWidget {
  const RecentVisitedLocationsPanel({
    super.key,
    required this.visits,
    required this.isLoading,
    this.error,
  });

  final List<Visit> visits;
  final bool isLoading;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppSurfaces.card(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppSurfaces.border(context)),
        ),
        child: Text(
          'Loading recent locations…',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppSurfaces.textMuted(context),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    if (error != null) {
      return const _UnavailableActivityCard(
        message: 'Recent locations are unavailable right now.',
      );
    }
    if (visits.isEmpty) {
      return const _UnavailableActivityCard(
        message: 'No recent locations yet.',
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppSurfaces.border(context)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < visits.length; index += 1) ...[
            Row(
              children: [
                Icon(
                  Icons.place_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    visits[index].displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppSurfaces.textPrimary(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (index != visits.length - 1)
              Divider(height: 18, color: AppSurfaces.border(context)),
          ],
        ],
      ),
    );
  }
}

/// Compact profile media preview sourced from visible activity media.
class ProfileMediaPreviewSection extends StatelessWidget {
  const ProfileMediaPreviewSection({
    super.key,
    required this.profileId,
    this.currentUserId,
    this.activitiesStream,
    this.activities,
  });

  final String profileId;
  final String? currentUserId;
  final Stream<List<ActivityFeedItem>>? activitiesStream;
  final List<ActivityFeedItem>? activities;

  @override
  Widget build(BuildContext context) {
    final activityItems = activities;
    if (activityItems != null) {
      return _buildPreview(context, activityItems);
    }
    final stream = activitiesStream;
    if (stream == null) return const SizedBox.shrink();
    return StreamBuilder<List<ActivityFeedItem>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();
        return _buildPreview(context, snapshot.data);
      },
    );
  }

  Widget _buildPreview(
    BuildContext context,
    List<ActivityFeedItem>? activityItems,
  ) {
    final entries = _mediaEntries(activityItems);
    if (entries.isEmpty) return const SizedBox.shrink();
    final previewEntries = entries.take(4).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Media',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppSurfaces.textPrimary(context),
          ),
        ),
        const SizedBox(height: 9),
        LayoutBuilder(
          builder: (context, constraints) {
            final tileSize = ((constraints.maxWidth - 24) / 4)
                .clamp(58.0, 74.0)
                .toDouble();
            return Row(
              children: [
                for (var index = 0; index < previewEntries.length; index += 1)
                  Padding(
                    padding: EdgeInsets.only(
                      right: index == previewEntries.length - 1 ? 0 : 8,
                    ),
                    child: SizedBox.square(
                      dimension: tileSize,
                      child: _ProfileMediaPreviewTile(
                        media: previewEntries[index].media,
                        showViewAllOverlay: index == previewEntries.length - 1,
                        onTap: index == previewEntries.length - 1
                            ? () => _openGallery(context)
                            : () => MediaViewer.show(
                                context: context,
                                mediaUrls: entries
                                    .map((entry) => entry.media.url)
                                    .toList(growable: false),
                                initialIndex: index,
                              ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _openGallery(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActivityMediaGalleryScreen(
          profileId: profileId,
          currentUserId: currentUserId,
        ),
      ),
    );
  }

  List<_ProfileMediaPreviewEntry> _mediaEntries(
    List<ActivityFeedItem>? activities,
  ) {
    final entries = <_ProfileMediaPreviewEntry>[];
    for (final activity in activities ?? const <ActivityFeedItem>[]) {
      for (final media in activity.media) {
        entries.add(_ProfileMediaPreviewEntry(media: media));
      }
    }
    return entries;
  }
}

class _ProfileMediaPreviewEntry {
  const _ProfileMediaPreviewEntry({required this.media});

  final ActivityMediaItem media;
}

class _ProfileMediaPreviewTile extends StatelessWidget {
  const _ProfileMediaPreviewTile({
    required this.media,
    required this.showViewAllOverlay,
    required this.onTap,
  });

  final ActivityMediaItem media;
  final bool showViewAllOverlay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (media.isVideo && (media.thumbnailUrl ?? '').isEmpty)
                ColoredBox(
                  color: AppSurfaces.softCard(context),
                  child: Icon(
                    Icons.videocam_outlined,
                    color: AppSurfaces.textMuted(context),
                  ),
                )
              else
                Image.network(
                  media.thumbnailUrl?.isNotEmpty == true
                      ? media.thumbnailUrl!
                      : media.url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: AppSurfaces.softCard(context),
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppSurfaces.textMuted(context),
                    ),
                  ),
                ),
              if (media.isVideo)
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              if (showViewAllOverlay)
                ColoredBox(
                  color: Colors.black.withValues(alpha: 0.48),
                  child: const Center(
                    child: Text(
                      'View all media',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        height: 1.05,
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
}

/// Shared section title with lower dashboard scale.
class ProfileSectionTitle extends StatelessWidget {
  const ProfileSectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: AppSurfaces.textPrimary(context),
        ),
      ),
    );
  }
}

class _UnavailableActivityCard extends StatelessWidget {
  const _UnavailableActivityCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppSurfaces.border(context)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppSurfaces.textMuted(context),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActivityLineChartPainter extends CustomPainter {
  const _ActivityLineChartPainter({
    required this.buckets,
    required this.selectedIndex,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.labelColor,
    required this.axisLabelColor,
  });

  final List<_MetricBucket> buckets;
  final int? selectedIndex;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final Color labelColor;
  final Color axisLabelColor;

  static const double _leftPad = 34;
  static const double _rightPad = 8;
  static const double _topPad = 12;
  static const double _bottomPad = 30;

  List<Offset> pointOffsets(Size size) {
    final chartLeft = _leftPad;
    final chartRight = size.width - _rightPad;
    final chartTop = _topPad;
    final chartBottom = size.height - _bottomPad;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;
    final maxValue = _maxValue();
    final points = <Offset>[];

    for (var index = 0; index < buckets.length; index += 1) {
      final bucket = buckets[index];
      final x = buckets.length == 1
          ? chartLeft + chartWidth / 2
          : chartLeft + chartWidth * index / (buckets.length - 1);
      final y = chartBottom - (chartHeight * bucket.value / maxValue);
      points.add(Offset(x, y));
    }
    return points;
  }

  int _maxValue() {
    return buckets
        .map((bucket) => bucket.value)
        .fold<int>(1, (max, value) => value > max ? value : max);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final chartLeft = _leftPad;
    final chartRight = size.width - _rightPad;
    final chartTop = _topPad;
    final chartBottom = size.height - _bottomPad;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;
    final maxValue = _maxValue();
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    final pointBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final guidePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.45)
      ..strokeWidth = 1.5;
    final labelStyle = TextStyle(
      color: labelColor,
      fontSize: 9,
      fontWeight: FontWeight.w700,
    );
    final yLabelStyle = TextStyle(
      color: axisLabelColor,
      fontSize: 9,
      fontWeight: FontWeight.w700,
    );

    for (var i = 0; i < 3; i += 1) {
      final fraction = i / 2;
      final y = chartTop + chartHeight * fraction;
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);

      final tickValue = (maxValue * (1 - fraction)).round();
      final yPainter = TextPainter(
        text: TextSpan(text: '$tickValue', style: yLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: _leftPad - 4);
      yPainter.paint(
        canvas,
        Offset(chartLeft - yPainter.width - 6, y - yPainter.height / 2),
      );
    }

    final points = pointOffsets(size);
    if (points.isNotEmpty) {
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        linePath.lineTo(point.dx, point.dy);
      }
      final fillPath = Path.from(linePath)
        ..lineTo(points.last.dx, chartBottom)
        ..lineTo(points.first.dx, chartBottom)
        ..close();

      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(linePath, linePaint);

      for (var index = 0; index < points.length; index += 1) {
        final point = points[index];
        final isSelected = selectedIndex == index;
        if (isSelected) {
          canvas.drawLine(
            Offset(point.dx, chartTop),
            Offset(point.dx, chartBottom),
            guidePaint,
          );
        }
        final radius = isSelected ? 6.5 : 4.5;
        canvas.drawCircle(point, radius, pointPaint);
        canvas.drawCircle(point, radius, pointBorderPaint);
      }
    }

    final slotWidth = buckets.length <= 1
        ? chartWidth
        : chartWidth / (buckets.length - 1);
    for (var index = 0; index < buckets.length; index += 1) {
      final bucket = buckets[index];
      final labelPainter = TextPainter(
        text: TextSpan(text: bucket.label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: slotWidth + 16);
      final x = buckets.length == 1
          ? chartLeft + chartWidth / 2
          : chartLeft + chartWidth * index / (buckets.length - 1);
      labelPainter.paint(
        canvas,
        Offset(
          (x - labelPainter.width / 2).clamp(
            chartLeft,
            chartRight - labelPainter.width,
          ),
          chartBottom + 10,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityLineChartPainter oldDelegate) {
    return oldDelegate.buckets != buckets ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.axisLabelColor != axisLabelColor;
  }
}

extension _ProfileGraphMetricLabel on ProfileGraphMetric {
  String get label {
    switch (this) {
      case ProfileGraphMetric.locationsVisited:
        return 'Locations Visited';
      case ProfileGraphMetric.tilesUnlocked:
        return 'Tiles Unlocked';
      case ProfileGraphMetric.journeysCompleted:
        return 'Journeys Completed';
      case ProfileGraphMetric.sidequestsCompleted:
        return 'Sidequests Completed';
      case ProfileGraphMetric.xpGained:
        return 'XP Gained';
    }
  }

  String get emptyMessage {
    switch (this) {
      case ProfileGraphMetric.locationsVisited:
        return 'No locations to chart yet';
      case ProfileGraphMetric.tilesUnlocked:
        return 'No unlocked tiles to chart yet';
      case ProfileGraphMetric.journeysCompleted:
        return 'Journey completion history is not available yet';
      case ProfileGraphMetric.sidequestsCompleted:
        return 'Sidequest completion history is not available yet';
      case ProfileGraphMetric.xpGained:
        return 'No XP gained yet this period';
    }
  }
}

class _MetricBucket {
  const _MetricBucket({
    required this.label,
    required this.value,
    required this.weekStart,
  });

  final String label;
  final int value;
  final DateTime weekStart;

  String detailLabel(ProfileGraphMetric metric) {
    final weekLabel = _weekAxisLabel(weekStart);
    switch (metric) {
      case ProfileGraphMetric.locationsVisited:
        return 'Week of $weekLabel · $value Locations Visited';
      case ProfileGraphMetric.tilesUnlocked:
        return 'Week of $weekLabel · $value Tiles Unlocked';
      case ProfileGraphMetric.journeysCompleted:
        return 'Week of $weekLabel · $value Journeys Completed';
      case ProfileGraphMetric.sidequestsCompleted:
        return 'Week of $weekLabel · $value Sidequests Completed';
      case ProfileGraphMetric.xpGained:
        return 'Week of $weekLabel · $value XP';
    }
  }
}

List<_MetricBucket> _weeklyBucketsFromDates(List<DateTime> dates) {
  final anchor = dates.isEmpty
      ? _startOfWeek(DateTime.now())
      : _startOfWeek(
          dates.reduce(
            (latest, value) => value.isAfter(latest) ? value : latest,
          ),
        );
  final starts = List<DateTime>.generate(
    6,
    (index) => anchor.subtract(Duration(days: 7 * (5 - index))),
  );

  return starts.map((start) {
    final end = start.add(const Duration(days: 7));
    final count = dates
        .where((date) => !date.isBefore(start) && date.isBefore(end))
        .length;
    return _MetricBucket(
      label: _weekAxisLabel(start),
      value: count,
      weekStart: start,
    );
  }).toList();
}

List<_MetricBucket> _weeklyBucketsFromXpEvents(List<XpEvent> events) {
  final dates = events.map((event) => event.earnedAt).toList();
  final anchor = dates.isEmpty
      ? _startOfWeek(DateTime.now())
      : _startOfWeek(
          dates.reduce(
            (latest, value) => value.isAfter(latest) ? value : latest,
          ),
        );
  final starts = List<DateTime>.generate(
    6,
    (index) => anchor.subtract(Duration(days: 7 * (5 - index))),
  );

  return starts.map((start) {
    final end = start.add(const Duration(days: 7));
    final xp = events
        .where(
          (event) =>
              !event.earnedAt.isBefore(start) && event.earnedAt.isBefore(end),
        )
        .fold<int>(0, (sum, event) => sum + event.amount);
    return _MetricBucket(
      label: _weekAxisLabel(start),
      value: xp,
      weekStart: start,
    );
  }).toList();
}

List<_MetricBucket> _emptyRecentBuckets() {
  final anchor = _startOfWeek(DateTime.now());
  return List<_MetricBucket>.generate(6, (index) {
    final start = anchor.subtract(Duration(days: 7 * (5 - index)));
    return _MetricBucket(
      label: _weekAxisLabel(start),
      value: 0,
      weekStart: start,
    );
  });
}

DateTime _startOfWeek(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  return local.subtract(Duration(days: local.weekday - DateTime.monday));
}

String _weekAxisLabel(DateTime date) {
  return '${date.day}/${date.month}';
}
