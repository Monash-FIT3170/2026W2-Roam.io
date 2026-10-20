/*
 * Author: Amarprit Singh
 * Last Updated: 4 October 2026
 * Description:
 *   Route visual for a Profile journey card, framed 16:9 edge to edge so the
 *   map supports the stats instead of filling most of the card.
 */

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../theme/app_surfaces.dart';
import '../../../activity_feed/data/activity_map_image.dart';
import '../../../activity_feed/data/activity_mutation_service.dart';
import '../../../activity_feed/domain/activity_route.dart';
import '../../../activity_feed/models/activity_feed_item.dart';
import '../../../activity_feed/widgets/activity_map_preview.dart';
import '../../../journeys/domain/transport_mode.dart';

/// Shape of the map slot on Profile journey cards.
const double kJourneyCardVisualAspectRatio = 16 / 9;

class JourneyMapPreview extends StatelessWidget {
  const JourneyMapPreview._({
    required this.activity,
    required this.route,
    this.currentUserId,
    this.onTap,
  });

  /// A preview for [activity], or null when it has no map to show.
  static JourneyMapPreview? maybe({
    required ActivityFeedItem activity,
    String? currentUserId,
    VoidCallback? onTap,
  }) {
    if (!activity.showMapPreview) return null;
    if (activity.hasMapImage) {
      return JourneyMapPreview._(
        activity: activity,
        route: null,
        currentUserId: currentUserId,
        onTap: onTap,
      );
    }
    final route = ActivityRoute.tryCreate(
      encodedRoute: activity.encodedRoute,
      persistedBounds: activity.routeBounds,
    );
    if (route == null) return null;
    return JourneyMapPreview._(
      activity: activity,
      route: route,
      currentUserId: currentUserId,
      onTap: onTap,
    );
  }

  final ActivityFeedItem activity;

  /// Set only when there is no stored picture and a live map stands in.
  final ActivityRoute? route;
  final String? currentUserId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final storedUrl = activity.mapImageUrl;
    final route = this.route;

    // The stored picture already has the route, its endpoints and the
    // poster's fog drawn in, so it is cropped to the card's frame rather than
    // restyled. Cropping 4:3 to 16:9 takes about 9% of the width off the top
    // and bottom, slightly more than the padding the capture leaves around the
    // route, so a route that fills the frame vertically can lose a few pixels
    // — or the tip of a flag — at its top and bottom.
    final Widget visual = storedUrl != null && storedUrl.isNotEmpty
        ? Image.network(
            storedUrl,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) =>
                const _MapUnavailable(),
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              final captureHeight =
                  constraints.maxWidth / ActivityMapImage.aspectRatio;
              // The live map is laid out in the stored picture's shape and
              // cropped, so a capture it backfills fits every other surface
              // that shows the picture at that shape.
              return ClipRect(
                child: OverflowBox(
                  minHeight: captureHeight,
                  maxHeight: captureHeight,
                  child: ActivityMapPreview(
                    key: ValueKey<String>('profile-journey-map-${activity.id}'),
                    route: route,
                    snapshotProfileId: activity.ownerId,
                    transportMode: TransportMode.tryFromString(
                      activity.transportMode,
                    ),
                    showEndpoints: true,
                    mapIdentity: activity.id,
                    onSnapshotCaptured: _mapImageBackfill,
                  ),
                ),
              );
            },
          );

    if (onTap == null) return visual;
    return Semantics(
      button: true,
      label: 'Open journey details',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: visual,
      ),
    );
  }

  /// Stores the live map's capture for an activity published before captures
  /// existed. Only the owner may write it.
  ValueChanged<Uint8List>? get _mapImageBackfill {
    final id = activity.id;
    final ownerId = activity.ownerId;
    if (id.isEmpty || ownerId.isEmpty || currentUserId != ownerId) return null;
    if (!ActivityMapImageBackfill.isPending(id)) return null;

    return (bytes) => unawaited(
      ActivityMapImageBackfill.record(
        activityId: id,
        ownerId: ownerId,
        bytes: bytes,
        mutationService: ActivityMutationService(),
      ),
    );
  }
}

class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppSurfaces.softCard(context),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              color: AppSurfaces.textMuted(context),
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              'Map preview unavailable',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppSurfaces.textMuted(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
