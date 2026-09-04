/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 22 August 2026
 * Description:
 *   Reusable activity feed card for persisted Home, You, external profile, and
 *   detail activity surfaces. Engagement is configurable via showKudos /
 *   showComments / showShare and reads live Firestore subcollection counts.
 *   Glaze is the product-facing name for persisted Kudos interactions.
 */

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_surfaces.dart';
import '../../journeys/domain/transport_mode.dart';
import '../../map/data/journey_map_snapshot_service.dart';
import '../../map/data/visited_region_service.dart';
import '../../social/widgets/social_avatar.dart';
import '../data/activity_map_image.dart';
import '../data/activity_mutation_service.dart';
import '../data/comment_service.dart';
import '../data/kudos_service.dart';
import '../domain/activity_route.dart';
import '../models/activity_comment.dart';
import '../models/activity_feed_item.dart';
import 'activity_glazers_sheet.dart';
import 'activity_media_carousel.dart';
import 'activity_map_preview.dart';
import 'route_marker_icons.dart';

export '../models/activity_feed_item.dart' show ActivityFeedMetric;

/// Presentation card for a personal or social activity feed entry.
class ActivityFeedCard extends StatelessWidget {
  const ActivityFeedCard({
    super.key,
    required this.displayName,
    required this.timestampLabel,
    required this.title,
    required this.metrics,
    this.activityId,
    this.activityOwnerId,
    this.currentUserId,
    this.commentService,
    this.kudosService,
    this.commentCountStream,
    this.photoUrl,
    this.username,
    this.showMapPreview = false,
    this.route,
    this.routeTransportMode,
    this.routeSnapshotProfileId,
    this.mapImageUrl,
    this.mapSnapshotService,
    this.visitedRegionService,
    this.mutationService,
    this.endpointMarkerIcons,
    this.media = const <ActivityMediaItem>[],
    this.onMediaTap,
    this.showKudos = true,
    this.showComments = true,
    this.showShare = true,
    this.onOverflowTap,
    this.onKudosTap,
    this.onCommentTap,
    this.onShareTap,
    this.kudosLabel = 'Glaze',
    this.commentLabel = 'Comment',
    this.shareLabel = 'Share',
  });

  /// Builds a card from a shared [ActivityFeedItem] model.
  factory ActivityFeedCard.fromItem(
    ActivityFeedItem item, {
    Key? key,
    CommentService? commentService,
    KudosService? kudosService,
    Stream<int>? commentCountStream,
    String? currentUserId,
    bool showKudos = true,
    bool showComments = true,
    bool showShare = true,
    VoidCallback? onOverflowTap,
    VoidCallback? onKudosTap,
    VoidCallback? onCommentTap,
    VoidCallback? onShareTap,
    JourneyMapSnapshotService? mapSnapshotService,
    VisitedRegionService? visitedRegionService,
    ActivityMutationService? mutationService,
    RouteEndpointMarkerIcons? endpointMarkerIcons,
  }) {
    final route = item.showMapPreview
        ? ActivityRoute.tryCreate(
            encodedRoute: item.encodedRoute,
            persistedBounds: item.routeBounds,
          )
        : null;

    return ActivityFeedCard(
      key: key,
      activityId: item.id,
      activityOwnerId: item.ownerId,
      currentUserId: currentUserId,
      commentService: commentService,
      kudosService: kudosService,
      commentCountStream: commentCountStream,
      displayName: item.displayName,
      username: item.username,
      photoUrl: item.photoUrl,
      timestampLabel: item.timestampLabel,
      title: item.title,
      metrics: item.metrics,
      showMapPreview: item.showMapPreview,
      route: route,
      routeTransportMode: TransportMode.tryFromString(item.transportMode),
      routeSnapshotProfileId: item.ownerId,
      mapImageUrl: item.mapImageUrl,
      mapSnapshotService: mapSnapshotService,
      visitedRegionService: visitedRegionService,
      mutationService: mutationService,
      endpointMarkerIcons: endpointMarkerIcons,
      media: item.media,
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

  /// Stable persisted activity id used for live interaction counts.
  final String? activityId;
  final String? activityOwnerId;
  final String? currentUserId;
  final CommentService? commentService;
  final KudosService? kudosService;

  /// Injected count stream for tests; production uses [commentService].
  final Stream<int>? commentCountStream;

  final bool showMapPreview;
  final ActivityRoute? route;
  final TransportMode? routeTransportMode;
  final String? routeSnapshotProfileId;

  /// Map picture stored when the journey was saved, fog already drawn on it.
  final String? mapImageUrl;
  final JourneyMapSnapshotService? mapSnapshotService;
  final VisitedRegionService? visitedRegionService;
  final ActivityMutationService? mutationService;
  final RouteEndpointMarkerIcons? endpointMarkerIcons;
  final List<ActivityMediaItem> media;
  final ValueChanged<int>? onMediaTap;
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

  Stream<int>? get _resolvedCommentCountStream {
    if (!showComments) {
      return null;
    }
    if (commentCountStream != null) {
      return commentCountStream;
    }
    final id = activityId;
    final service = commentService;
    if (id != null && service != null) {
      return service.watchCommentCount(id);
    }
    // Widget tests / layouts without a service: show a stable zero count.
    return Stream<int>.value(0);
  }

  Stream<int>? get _resolvedKudosCountStream {
    if (!showKudos) return null;
    final id = activityId;
    final service = kudosService;
    if (id != null && service != null) {
      return service.watchKudosCount(id);
    }
    return Stream<int>.value(0);
  }

  Stream<bool>? get _resolvedHasKudosStream {
    final id = activityId;
    final uid = currentUserId;
    final service = kudosService;
    if (!showKudos || id == null || uid == null || service == null) {
      return null;
    }
    return service.watchHasGivenKudos(activityId: id, userId: uid);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countStream = _resolvedCommentCountStream;
    final kudosCountStream = _resolvedKudosCountStream;
    final hasKudosStream = _resolvedHasKudosStream;
    final routeSlide = _buildRouteSlide();

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
              SocialAvatar(
                displayName: displayName,
                photoUrl: photoUrl,
                radius: 22,
                borderWidth: 1.5,
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
          if (media.isNotEmpty || routeSlide != null) ...[
            const SizedBox(height: 12),
            ActivityMediaCarousel(
              media: media,
              onTap: onMediaTap,
              routeSlide: routeSlide,
            ),
          ],
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 14),
            ActivityMetricsRow(metrics: metrics),
          ],
          if (_hasEngagementActions) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: AppSurfaces.border(context)),
            const SizedBox(height: 4),
            Row(
              children: [
                if (showKudos)
                  _KudosActionButton(
                    countStream: kudosCountStream,
                    hasKudosStream: hasKudosStream,
                    fallbackLabel: kudosLabel,
                    activityId: activityId,
                    onTap: onKudosTap ?? () => _toggleKudos(context),
                  ),
                if (showComments)
                  _CommentActionButton(
                    countStream: countStream,
                    fallbackLabel: commentLabel,
                    activityId: activityId,
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

  /// The route slide: the stored picture when there is one, otherwise a live
  /// map that doubles as the capture source for the activity's owner.
  Widget? _buildRouteSlide() {
    if (!showMapPreview) return null;

    final storedMapImageUrl = mapImageUrl;
    if (storedMapImageUrl != null && storedMapImageUrl.isNotEmpty) {
      return ActivityMapSnapshotImage(
        key: ValueKey<String>('activity-card-map-image-$activityId'),
        url: storedMapImageUrl,
      );
    }

    if (route == null) return null;

    return ActivityMapPreview(
      key: ValueKey<String>('activity-card-map-$activityId'),
      route: route,
      snapshotProfileId: routeSnapshotProfileId,
      mapSnapshotService: mapSnapshotService,
      visitedRegionService: visitedRegionService,
      transportMode: routeTransportMode,
      showEndpoints: true,
      endpointMarkerIcons: endpointMarkerIcons,
      mapIdentity: activityId,
      onSnapshotCaptured: _mapImageBackfill,
    );
  }

  /// Capture handler for an activity saved before the picture existed.
  ///
  /// Only the owner can write the picture, so nobody else's card wastes a
  /// snapshot on it.
  ValueChanged<Uint8List>? get _mapImageBackfill {
    final id = activityId;
    final ownerId = activityOwnerId;
    if (id == null || id.isEmpty || ownerId == null || ownerId.isEmpty) {
      return null;
    }
    if (currentUserId != ownerId) return null;
    if (!ActivityMapImageBackfill.isPending(id)) return null;

    return (bytes) => unawaited(
      ActivityMapImageBackfill.record(
        activityId: id,
        ownerId: ownerId,
        bytes: bytes,
        mutationService: mutationService ?? ActivityMutationService(),
      ),
    );
  }

  Future<void> _toggleKudos(BuildContext context) async {
    final id = activityId;
    final ownerId = activityOwnerId;
    final uid = currentUserId;
    final service = kudosService;
    if (id == null || ownerId == null || uid == null || service == null) {
      debugPrint(
        '[ActivityFeedCard] kudos skipped activityId=$id ownerId=$ownerId '
        'userId=$uid hasService=${service != null}',
      );
      return;
    }
    if (uid == ownerId) {
      await ActivityGlazersSheet.show(
        context: context,
        activityId: id,
        kudosService: service,
      );
      return;
    }
    debugPrint(
      '[ActivityFeedCard] toggleKudos activityId=$id ownerId=$ownerId '
      'userId=$uid',
    );
    try {
      await service.toggleKudos(
        activityId: id,
        activityOwnerId: ownerId,
        userId: uid,
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[ActivityFeedCard] toggleKudos failed activityId=$id '
        'error=$error\n$stackTrace',
      );
      if (context.mounted) {
        AppToast.error(context, 'Could not update Glaze. Try again.');
      }
    }
  }
}

/// Shared equal-width, centre-aligned metric columns for cards and detail.
class ActivityMetricsRow extends StatelessWidget {
  const ActivityMetricsRow({super.key, required this.metrics, this.valueStyle});

  final List<ActivityFeedMetric> metrics;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        for (var index = 0; index < metrics.length; index += 1)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      metrics[index].label,
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppSurfaces.textMuted(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      metrics[index].value,
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.center,
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
          ),
      ],
    );
  }
}

class _CommentActionButton extends StatelessWidget {
  const _CommentActionButton({
    required this.countStream,
    required this.fallbackLabel,
    required this.onTap,
    this.activityId,
  });

  final Stream<int>? countStream;
  final String fallbackLabel;
  final VoidCallback? onTap;
  final String? activityId;

  @override
  Widget build(BuildContext context) {
    if (countStream == null) {
      return _ActionButton(
        icon: Icons.chat_bubble_outline_rounded,
        label: fallbackLabel,
        onTap: onTap,
      );
    }

    return Expanded(
      child: StreamBuilder<int>(
        stream: countStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint(
              '[ActivityFeedCard] comment count failed '
              'activityId=$activityId error=${snapshot.error}',
            );
            return _ActionButton(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Comments',
              onTap: onTap,
              expand: false,
            );
          }
          if (!snapshot.hasData) {
            return _ActionButton(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Comments',
              onTap: onTap,
              expand: false,
            );
          }
          final count = snapshot.data!;
          return _ActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: formatCommentCount(count),
            onTap: onTap,
            expand: false,
          );
        },
      ),
    );
  }
}

class _KudosActionButton extends StatelessWidget {
  const _KudosActionButton({
    required this.countStream,
    required this.hasKudosStream,
    required this.fallbackLabel,
    required this.onTap,
    this.activityId,
  });

  final Stream<int>? countStream;
  final Stream<bool>? hasKudosStream;
  final String fallbackLabel;
  final VoidCallback? onTap;
  final String? activityId;

  @override
  Widget build(BuildContext context) {
    if (countStream == null) {
      return _ActionButton(
        icon: Icons.thumb_up_alt_outlined,
        label: fallbackLabel,
        onTap: onTap,
      );
    }

    return Expanded(
      child: StreamBuilder<int>(
        stream: countStream,
        builder: (context, countSnapshot) {
          if (countSnapshot.hasError) {
            debugPrint(
              '[ActivityFeedCard] kudos count failed '
              'activityId=$activityId error=${countSnapshot.error}',
            );
            return _ActionButton(
              icon: Icons.thumb_up_alt_outlined,
              label: fallbackLabel,
              onTap: onTap,
              expand: false,
            );
          }
          final count = countSnapshot.hasData ? countSnapshot.data! : null;
          if (hasKudosStream == null) {
            return _ActionButton(
              icon: Icons.thumb_up_alt_outlined,
              label: count == null ? fallbackLabel : _formatKudosCount(count),
              onTap: onTap,
              expand: false,
            );
          }
          return StreamBuilder<bool>(
            stream: hasKudosStream,
            builder: (context, stateSnapshot) {
              if (stateSnapshot.hasError) {
                debugPrint(
                  '[ActivityFeedCard] hasKudos failed '
                  'activityId=$activityId error=${stateSnapshot.error}',
                );
              }
              final hasKudos = stateSnapshot.data ?? false;
              return _ActionButton(
                icon: hasKudos
                    ? Icons.thumb_up_alt_rounded
                    : Icons.thumb_up_alt_outlined,
                label: count == null ? fallbackLabel : _formatKudosCount(count),
                onTap: onTap,
                expand: false,
                active: hasKudos,
              );
            },
          );
        },
      ),
    );
  }
}

/// Equal-width engagement action. Labels scale down instead of ellipsizing so
/// Glaze / comment counts / Share stay fully readable in a 2- or 3-button row.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.expand = true,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool expand;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: active
                    ? theme.colorScheme.primary
                    : AppSurfaces.textMuted(context),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: active
                      ? theme.colorScheme.primary
                      : AppSurfaces.textMuted(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!expand) {
      return content;
    }
    return Expanded(child: content);
  }
}

String _formatKudosCount(int count) {
  if (count <= 0) return 'Glaze';
  return count == 1 ? '1 Glaze' : '$count Glaze';
}
