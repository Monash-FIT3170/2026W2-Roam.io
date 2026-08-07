/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Expanded journey/activity detail screen opened from activity feed cards.
 *   Personal detail (You → Activities) omits engagement controls by default.
 *   Metric labels stay on one line via shared ActivityMetricsRow.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';
import '../models/activity_feed_item.dart';
import '../widgets/activity_feed_card.dart';
import '../widgets/activity_map_preview.dart';

/// Full-screen detail view for a single activity feed item.
class ActivityDetailScreen extends StatelessWidget {
  const ActivityDetailScreen({
    super.key,
    required this.activity,
    this.showEngagementActions = false,
  });

  final ActivityFeedItem activity;

  /// When true, shows Kudos/Comment/Share. Personal journeys keep this false.
  final bool showEngagementActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: AppSurfaces.pageBackground(context),
      appBar: AppBar(
        backgroundColor: AppSurfaces.pageBackground(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppSurfaces.softCard(context),
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.primary, width: 1.5),
                  ),
                  child: ClipOval(
                    child:
                        activity.photoUrl != null &&
                            activity.photoUrl!.isNotEmpty
                        ? Image.network(
                            activity.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.person_rounded,
                              color: colorScheme.primary,
                            ),
                          )
                        : Icon(
                            Icons.person_rounded,
                            color: colorScheme.primary,
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppSurfaces.textPrimary(context),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activity.timestampLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppSurfaces.textMuted(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              activity.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppSurfaces.textPrimary(context),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            const ActivityMapPreview(expanded: true),
            if (activity.metrics.isNotEmpty) ...[
              const SizedBox(height: 20),
              ActivityMetricsRow(
                metrics: activity.metrics,
                valueStyle: theme.textTheme.titleMedium?.copyWith(
                  color: AppSurfaces.textPrimary(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
            if (showEngagementActions) ...[
              const SizedBox(height: 24),
              Divider(height: 1, color: AppSurfaces.border(context)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _DetailAction(
                    icon: Icons.thumb_up_alt_outlined,
                    label: 'Kudos',
                    onTap: () {},
                  ),
                  _DetailAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Comment',
                    onTap: () {},
                  ),
                  _DetailAction(
                    icon: Icons.ios_share_rounded,
                    label: 'Share',
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailAction extends StatelessWidget {
  const _DetailAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: AppSurfaces.textMuted(context)),
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
