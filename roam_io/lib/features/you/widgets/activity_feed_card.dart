/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 5 August 2026
 * Description:
 *   Reusable activity/feed card presentation for the You Activities tab and
 *   future friend activity feeds. Visual prototype only — kudos, comment, and
 *   share callbacks are optional and do not persist by default.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';

/// A single activity metric shown in the card body (label above value).
class ActivityFeedMetric {
  const ActivityFeedMetric({required this.label, required this.value});

  final String label;
  final String value;
}

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
    this.activityTypeIcon = Icons.fitness_center_rounded,
    this.onOverflowTap,
    this.onKudosTap,
    this.onCommentTap,
    this.onShareTap,
    this.kudosLabel = 'Kudos',
    this.commentLabel = 'Comment',
    this.shareLabel = 'Share',
  });

  final String displayName;
  final String? username;
  final String? photoUrl;
  final String timestampLabel;
  final String title;
  final IconData activityTypeIcon;
  final List<ActivityFeedMetric> metrics;
  final VoidCallback? onOverflowTap;
  final VoidCallback? onKudosTap;
  final VoidCallback? onCommentTap;
  final VoidCallback? onShareTap;
  final String kudosLabel;
  final String commentLabel;
  final String shareLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final identity = username == null || username!.isEmpty
        ? displayName
        : displayName;

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
                      identity,
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
              Icon(activityTypeIcon, color: colorScheme.primary, size: 22),
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
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                for (var index = 0; index < metrics.length; index += 1) ...[
                  if (index > 0) const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metrics[index].label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppSurfaces.textMuted(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          metrics[index].value,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppSurfaces.textPrimary(context),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: AppSurfaces.border(context)),
          const SizedBox(height: 4),
          Row(
            children: [
              _ActionButton(
                icon: Icons.thumb_up_alt_outlined,
                label: kudosLabel,
                onTap: onKudosTap,
              ),
              _ActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: commentLabel,
                onTap: onCommentTap,
              ),
              _ActionButton(
                icon: Icons.ios_share_rounded,
                label: shareLabel,
                onTap: onShareTap,
              ),
            ],
          ),
        ],
      ),
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
