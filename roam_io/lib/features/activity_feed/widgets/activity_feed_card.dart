/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Reusable activity feed card for You → Activities (personal) and Home
 *   (friend stubs). Engagement actions are configurable for privacy:
 *   Home friends expose Kudos + Comment only (no Share). Personal cards keep
 *   Kudos/Comment/Share as UI placeholders. Metric labels stay on one line.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';
import '../models/activity_feed_item.dart';
import 'activity_map_preview.dart';

export '../models/activity_feed_item.dart' show ActivityFeedMetric;

/// Presentation card for a personal or social activity feed entry.
class ActivityFeedCard extends StatelessWidget {
  const ActivityFeedCard({
    super.key,
    required this.displayName,
    required this.timestampLabel,
    required this.title,
    required this.metrics,
    this.photoUrl,
    this.username,
    this.showMapPreview = false,
    this.showKudos = true,
    this.showComments = true,
    this.showShare = true,
    this.onOverflowTap,
    this.onKudosTap,
    this.onCommentTap,
    this.onShareTap,
    this.kudosLabel = 'Kudos',
    this.commentLabel = 'Comment',
    this.shareLabel = 'Share',
  });

  /// Builds a card from a shared [ActivityFeedItem] model.
  factory ActivityFeedCard.fromItem(
    ActivityFeedItem item, {
    Key? key,
    bool showKudos = true,
    bool showComments = true,
    bool showShare = true,
    VoidCallback? onOverflowTap,
    VoidCallback? onKudosTap,
    VoidCallback? onCommentTap,
    VoidCallback? onShareTap,
  }) {
    return ActivityFeedCard(
      key: key,
      displayName: item.displayName,
      username: item.username,
      photoUrl: item.photoUrl,
      timestampLabel: item.timestampLabel,
      title: item.title,
      metrics: item.metrics,
      showMapPreview: item.showMapPreview,
      showKudos: showKudos,
      showComments: showComments,
      showShare: showShare,
      onOverflowTap: onOverflowTap,
      onKudosTap: onKudosTap,
      onCommentTap: onCommentTap,
      onShareTap: onShareTap,
    );
  }

  final String displayName;
  final String? username;
  final String? photoUrl;
  final String timestampLabel;
  final String title;
  final List<ActivityFeedMetric> metrics;
  final bool showMapPreview;
  final bool showKudos;
  final bool showComments;
  final bool showShare;
  final VoidCallback? onOverflowTap;
  final VoidCallback? onKudosTap;
  final VoidCallback? onCommentTap;
  final VoidCallback? onShareTap;
  final String kudosLabel;
  final String commentLabel;
  final String shareLabel;

  bool get _hasEngagementActions => showKudos || showComments || showShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppSurfaces.softCard(context),
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.primary, width: 1.5),
                ),
                child: ClipOval(
                  child: photoUrl != null && photoUrl!.isNotEmpty
                      ? Image.network(
                          photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.person_rounded,
                            color: colorScheme.primary,
                          ),
                        )
                      : Icon(Icons.person_rounded, color: colorScheme.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppSurfaces.textPrimary(context),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timestampLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppSurfaces.textMuted(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: onOverflowTap,
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: AppSurfaces.textMuted(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppSurfaces.textPrimary(context),
              fontWeight: FontWeight.w900,
            ),
          ),
          if (showMapPreview) ...[
            const SizedBox(height: 12),
            const ActivityMapPreview(),
          ],
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 14),
            _ActivityMetricsRow(metrics: metrics),
          ],
          if (_hasEngagementActions) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: AppSurfaces.border(context)),
            const SizedBox(height: 4),
            Row(
              children: [
                if (showKudos)
                  _ActionButton(
                    icon: Icons.thumb_up_alt_outlined,
                    label: kudosLabel,
                    onTap: onKudosTap,
                  ),
                if (showComments)
                  _ActionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: commentLabel,
                    onTap: onCommentTap,
                  ),
                if (showShare)
                  _ActionButton(
                    icon: Icons.ios_share_rounded,
                    label: shareLabel,
                    onTap: onShareTap,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Shared one-line metric labels + values for cards and detail screens.
class ActivityMetricsRow extends StatelessWidget {
  const ActivityMetricsRow({super.key, required this.metrics, this.valueStyle});

  final List<ActivityFeedMetric> metrics;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return _ActivityMetricsRow(metrics: metrics, valueStyle: valueStyle);
  }
}

class _ActivityMetricsRow extends StatelessWidget {
  const _ActivityMetricsRow({required this.metrics, this.valueStyle});

  final List<ActivityFeedMetric> metrics;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        for (var index = 0; index < metrics.length; index += 1) ...[
          if (index > 0) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    metrics[index].label,
                    maxLines: 1,
                    softWrap: false,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppSurfaces.textMuted(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    metrics[index].value,
                    maxLines: 1,
                    softWrap: false,
                    style:
                        valueStyle ??
                        theme.textTheme.titleSmall?.copyWith(
                          color: AppSurfaces.textPrimary(context),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppSurfaces.textMuted(context)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppSurfaces.textMuted(context),
                    fontWeight: FontWeight.w800,
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
