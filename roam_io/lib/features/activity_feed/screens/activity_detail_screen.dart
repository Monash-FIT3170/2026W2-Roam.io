/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Expanded journey/activity detail screen opened from activity feed cards.
 *   Metric labels stay on one line via shared ActivityMetricsRow and
 *   engagement controls consume the same persisted services as feed cards.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';
import '../data/comment_like_service.dart';
import '../data/comment_service.dart';
import '../data/kudos_service.dart';
import '../models/activity_feed_item.dart';
import '../widgets/activity_feed_card.dart';
import '../widgets/activity_map_preview.dart';
import 'comments_screen.dart';
import '../../journeys/widgets/journey_share_sheet.dart';

/// Full-screen detail view for a single activity feed item.
class ActivityDetailScreen extends StatelessWidget {
  const ActivityDetailScreen({
    super.key,
    required this.activity,
    this.showEngagementActions = false,
    this.showShare = false,
    this.currentUserId,
    this.commentService,
    this.commentLikeService,
    this.kudosService,
  });

  final ActivityFeedItem activity;

  /// When true, shows Kudos/Comment/Share. Personal journeys keep this false.
  final bool showEngagementActions;
  final bool showShare;
  final String? currentUserId;
  final CommentService? commentService;
  final CommentLikeService? commentLikeService;
  final KudosService? kudosService;

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
                  _DetailKudosAction(
                    activity: activity,
                    currentUserId: currentUserId,
                    kudosService: kudosService,
                  ),
                  Expanded(
                    child: _DetailAction(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Comments',
                      countStream: commentService?.watchCommentCount(
                        activity.id,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CommentsScreen(
                              activityId: activity.id,
                              activityOwnerId: activity.ownerId,
                              commentService: commentService,
                              commentLikeService: commentLikeService,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (showShare)
                    Expanded(
                      child: _DetailAction(
                        icon: Icons.ios_share_rounded,
                        label: 'Share',
                        onTap: () {
                          JourneyShareSheet.shareFromActivity(context, activity);
                        },
                      ),
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
    this.countStream,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Stream<int>? countStream;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget buildButton(String resolvedLabel) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: active
                    ? theme.colorScheme.primary
                    : AppSurfaces.textMuted(context),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  resolvedLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: active
                        ? theme.colorScheme.primary
                        : AppSurfaces.textMuted(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (countStream == null) return buildButton(label);
    return StreamBuilder<int>(
      stream: countStream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        final resolved = count == 1 ? '1 comment' : '$count comments';
        return buildButton(resolved);
      },
    );
  }
}

class _DetailKudosAction extends StatelessWidget {
  const _DetailKudosAction({
    required this.activity,
    required this.currentUserId,
    required this.kudosService,
  });

  final ActivityFeedItem activity;
  final String? currentUserId;
  final KudosService? kudosService;

  @override
  Widget build(BuildContext context) {
    final service = kudosService;
    final uid = currentUserId;
    if (service == null || uid == null) {
      return Expanded(
        child: _DetailAction(
          icon: Icons.thumb_up_alt_outlined,
          label: 'Kudos',
          onTap: () {},
        ),
      );
    }

    return Expanded(
      child: StreamBuilder<int>(
        stream: service.watchKudosCount(activity.id),
        builder: (context, countSnapshot) {
          final count = countSnapshot.data ?? 0;
          return StreamBuilder<bool>(
            stream: service.watchHasGivenKudos(
              activityId: activity.id,
              userId: uid,
            ),
            builder: (context, stateSnapshot) {
              final hasKudos = stateSnapshot.data ?? false;
              final label = count <= 0
                  ? 'Kudos'
                  : (count == 1 ? '1 Kudos' : '$count Kudos');
              return _DetailAction(
                icon: hasKudos
                    ? Icons.thumb_up_alt_rounded
                    : Icons.thumb_up_alt_outlined,
                label: label,
                active: hasKudos,
                onTap: () {
                  service.toggleKudos(
                    activityId: activity.id,
                    activityOwnerId: activity.ownerId,
                    userId: uid,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
