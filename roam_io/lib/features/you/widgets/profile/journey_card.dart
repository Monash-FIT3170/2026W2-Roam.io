/*
 * Author: Amarprit Singh
 * Last Updated: 4 October 2026
 * Description:
 *   Strava-style journey card for the traveller's own Profile tab — date
 *   row, bold title, achievement chips, a DISTANCE / TIME / TILES / XP stat
 *   grid, the route and photos as one swipeable strip, then Glaze / Comment /
 *   Share.
 */

import 'package:flutter/material.dart';

import '../../../../shared/utils/app_date_format.dart';
import '../../../../theme/app_surfaces.dart';
import '../../../activity_feed/data/comment_service.dart';
import '../../../activity_feed/data/kudos_service.dart';
import '../../../activity_feed/widgets/activity_feed_card.dart';
import '../../../activity_feed/widgets/activity_media_carousel.dart';
import '../../../map/widgets/media_viewer.dart';
import '../../services/profile_feed_builder.dart';
import 'journey_map_preview.dart';
import 'profile_card.dart';
import 'stat_block.dart';

class JourneyCard extends StatelessWidget {
  const JourneyCard({
    super.key,
    required this.entry,
    this.currentUserId,
    this.commentService,
    this.kudosService,
    this.onOpen,
    this.onMenu,
    this.onCommentTap,
    this.onShareTap,
  });

  final ProfileJourneyEntry entry;
  final String? currentUserId;
  final CommentService? commentService;
  final KudosService? kudosService;

  /// Opens the journey's detail screen.
  final VoidCallback? onOpen;

  /// Opens the ••• options.
  final VoidCallback? onMenu;
  final VoidCallback? onCommentTap;
  final VoidCallback? onShareTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activity = entry.activity;
    final routeSlide = JourneyMapPreview.maybe(
      activity: activity,
      currentUserId: currentUserId,
      onTap: onOpen,
    );
    final hasVisual = routeSlide != null || activity.media.isNotEmpty;

    return ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 4, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DateRow(entry: entry, onMenu: onMenu),
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppSurfaces.textPrimary(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  if (entry.highlights.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final highlight in entry.highlights)
                          _HighlightChip(highlight: highlight),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _StatGrid(entry: entry),
                  ),
                ],
              ),
            ),
          ),
          if (hasVisual)
            ActivityMediaCarousel(
              media: activity.media,
              aspectRatio: kJourneyCardVisualAspectRatio,
              routeSlide: routeSlide,
              routeFirst: true,
              borderRadius: 0,
              onTap: activity.media.isEmpty
                  ? null
                  : (index) => MediaViewer.show(
                      context: context,
                      mediaUrls: activity.mediaUrls,
                      initialIndex: index,
                    ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
            child: ActivityEngagementRow(
              activityId: activity.id,
              activityOwnerId: activity.ownerId,
              currentUserId: currentUserId,
              commentService: commentService,
              kudosService: kudosService,
              onCommentTap: onCommentTap,
              onShareTap: onShareTap,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mode, when and where, plus the ••• menu. Every card here is the
/// traveller's own, so the owner's avatar and name are left to the header.
class _DateRow extends StatelessWidget {
  const _DateRow({required this.entry, this.onMenu});

  final ProfileJourneyEntry entry;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = entry.transportMode;
    final meta = [
      _whenLabel(entry),
      if (entry.placeLabel != null) entry.placeLabel!,
    ].join(' · ');

    return Row(
      children: [
        if (mode != null) ...[
          Icon(mode.icon, size: 15, color: AppSurfaces.textMuted(context)),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppSurfaces.textMuted(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Journey options',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          onPressed: onMenu,
          icon: Icon(
            Icons.more_horiz_rounded,
            color: AppSurfaces.textMuted(context),
          ),
        ),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.entry});

  final ProfileJourneyEntry entry;

  @override
  Widget build(BuildContext context) {
    final blocks = entry.isJourney
        ? _journeyBlocks(entry)
        : [
            for (final metric in entry.activity.metrics.take(4))
              StatBlock(
                label: metric.label,
                value: metric.value,
                accent: metric.label.toLowerCase().contains('xp'),
              ),
          ];
    if (blocks.isEmpty) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < blocks.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(child: blocks[index]),
        ],
      ],
    );
  }

  static List<StatBlock> _journeyBlocks(ProfileJourneyEntry entry) {
    final distanceMeters = entry.distanceMeters;
    final distance = distanceMeters == null
        ? null
        : formatProfileDistance(distanceMeters);
    final duration = entry.durationSeconds;
    final tiles = entry.tilesUnlocked;
    final xp = entry.xpEarned;
    return [
      StatBlock(
        label: 'Distance',
        value: distance?.value ?? '—',
        unit: distance?.unit,
      ),
      StatBlock(
        label: 'Time',
        value: duration == null ? '—' : formatProfileDuration(duration),
      ),
      StatBlock(label: 'Tiles', value: tiles == null ? '—' : '$tiles'),
      StatBlock(label: 'XP', value: xp == null ? '—' : '+$xp', accent: true),
    ];
  }
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({required this.highlight});

  final ProfileJourneyHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTrophy =
        highlight.kind == ProfileJourneyHighlightKind.longestThisMonth;
    final color = isTrophy
        ? theme.colorScheme.secondary
        : profileAccentColor(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isTrophy ? Icons.emoji_events_rounded : Icons.grid_view_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              highlight.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Start time for journeys; the post's own label for everything else, which
/// already reads "Recently" for posts with no usable date.
String _whenLabel(ProfileJourneyEntry entry) {
  final activity = entry.activity;
  if (entry.journey != null || activity.journeyStartTime != null) {
    return formatAppDateTime(entry.occurredAt);
  }
  return activity.timestampLabel;
}
