/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 22 August 2026
 * Description:
 *   Expanded journey/activity detail screen opened from activity feed cards.
 *   Metric labels stay on one line via shared ActivityMetricsRow and
 *   engagement controls consume the same persisted services as feed cards.
 *   Glaze is the product-facing name for persisted Kudos interactions.
 */

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../theme/app_surfaces.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../journeys/domain/transport_mode.dart';
import '../../journeys/widgets/journey_share_sheet.dart';
import '../../map/data/journey_map_snapshot_service.dart';
import '../../map/data/visited_region_service.dart';
import '../../map/widgets/media_viewer.dart';
import '../data/comment_like_service.dart';
import '../data/comment_service.dart';
import '../data/activity_mutation_service.dart';
import '../data/kudos_service.dart';
import '../domain/activity_route.dart';
import '../models/activity_feed_item.dart';
import '../widgets/activity_glazers_sheet.dart';
import '../widgets/activity_feed_card.dart';
import '../widgets/activity_map_preview.dart';
import '../widgets/activity_media_carousel.dart';
import '../widgets/route_marker_icons.dart';
import 'comments_screen.dart';

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
    this.mutationService,
    this.mapSnapshotService,
    this.visitedRegionService,
    this.endpointMarkerIcons,
  });

  final ActivityFeedItem activity;

  /// When true, shows Kudos/Comment/Share. Personal journeys keep this false.
  final bool showEngagementActions;
  final bool showShare;
  final String? currentUserId;
  final CommentService? commentService;
  final CommentLikeService? commentLikeService;
  final KudosService? kudosService;
  final ActivityMutationService? mutationService;
  final JourneyMapSnapshotService? mapSnapshotService;
  final VisitedRegionService? visitedRegionService;
  final RouteEndpointMarkerIcons? endpointMarkerIcons;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final route = activity.showMapPreview
        ? ActivityRoute.tryCreate(
            encodedRoute: activity.encodedRoute,
            persistedBounds: activity.routeBounds,
          )
        : null;
    final transportMode = TransportMode.tryFromString(activity.transportMode);
    final routeSlide = route == null
        ? null
        : ActivityMapPreview(
            key: const ValueKey('activity_route_map_detail'),
            route: route,
            variant: ActivityMapPreviewVariant.detail,
            snapshotProfileId: activity.ownerId,
            mapSnapshotService: mapSnapshotService,
            visitedRegionService: visitedRegionService,
            transportMode: transportMode,
            showEndpoints: true,
            endpointMarkerIcons: endpointMarkerIcons,
            mapIdentity: activity.id,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ActivityRouteMapScreen(
                    route: route,
                    title: activity.title,
                    transportMode: transportMode,
                    endpointMarkerIcons: endpointMarkerIcons,
                  ),
                ),
              );
            },
          );

    return Scaffold(
      backgroundColor: AppSurfaces.pageBackground(context),
      appBar: AppBar(
        backgroundColor: AppSurfaces.pageBackground(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BackButton(),
        actions: [
          if (currentUserId == activity.ownerId)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditDialog(context);
                } else if (value == 'delete') {
                  _confirmDelete(context);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
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
            if (activity.media.isNotEmpty || routeSlide != null) ...[
              ActivityMediaCarousel(
                media: activity.media,
                aspectRatio: 4 / 3,
                routeSlide: routeSlide,
                routeFirst: true,
                onTap: (index) => MediaViewer.show(
                  context: context,
                  mediaUrls: activity.mediaUrls,
                  initialIndex: index,
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (activity.metrics.isNotEmpty) ...[
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
                          JourneyShareSheet.shareFromActivity(
                            context,
                            activity,
                          );
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

  Future<void> _showEditDialog(BuildContext context) async {
    final service = mutationService ?? ActivityMutationService();
    final titleController = TextEditingController(text: activity.title);
    final editableMedia = List<ActivityMediaItem>.from(activity.media);
    final pendingMedia = <PendingActivityMedia>[];
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final mediaCount = editableMedia.length + pendingMedia.length;
          return AlertDialog(
            title: const Text('Edit Activity'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  if (editableMedia.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 90,
                      child: ReorderableListView.builder(
                        scrollDirection: Axis.horizontal,
                        buildDefaultDragHandles: false,
                        itemCount: editableMedia.length,
                        onReorder: (oldIndex, newIndex) {
                          if (newIndex > oldIndex) newIndex -= 1;
                          setDialogState(() {
                            final item = editableMedia.removeAt(oldIndex);
                            editableMedia.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final media = editableMedia[index];
                          return ReorderableDragStartListener(
                            key: ValueKey<String>('existing-${media.id}'),
                            index: index,
                            child: _EditableMediaTile(
                              isVideo: media.isVideo,
                              url: media.url,
                              onRemove: () => setDialogState(
                                () => editableMedia.removeAt(index),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  if (pendingMedia.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 90,
                      child: ReorderableListView.builder(
                        scrollDirection: Axis.horizontal,
                        buildDefaultDragHandles: false,
                        itemCount: pendingMedia.length,
                        onReorder: (oldIndex, newIndex) {
                          if (newIndex > oldIndex) newIndex -= 1;
                          setDialogState(() {
                            final item = pendingMedia.removeAt(oldIndex);
                            pendingMedia.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final media = pendingMedia[index];
                          return ReorderableDragStartListener(
                            key: ValueKey<String>('pending-${media.file.path}'),
                            index: index,
                            child: _EditableMediaTile(
                              isVideo: media.isVideo,
                              file: File(media.file.path),
                              onRemove: () => setDialogState(
                                () => pendingMedia.removeAt(index),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: mediaCount >= 3
                              ? null
                              : () async {
                                  final picked =
                                      await _pickEditMediaFromLibrary();
                                  if (picked == null) return;
                                  setDialogState(
                                    () => pendingMedia.add(picked),
                                  );
                                },
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Photo Library'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Take photo',
                        onPressed: mediaCount >= 3
                            ? null
                            : () async {
                                final picked = await _takeEditPhoto();
                                if (picked == null) return;
                                setDialogState(() => pendingMedia.add(picked));
                              },
                        icon: const Icon(Icons.photo_camera_outlined),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filledTonal(
                        tooltip: 'Record video',
                        onPressed: mediaCount >= 3
                            ? null
                            : () async {
                                final picked = await _takeEditVideo();
                                if (picked == null) return;
                                setDialogState(() => pendingMedia.add(picked));
                              },
                        icon: const Icon(Icons.videocam_outlined),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
    final editedTitle = titleController.text;
    titleController.dispose();
    if (result != true || !context.mounted) return;
    try {
      await service.updateActivityEditableFields(
        activity: activity,
        title: editedTitle,
        media: editableMedia,
        pendingMedia: pendingMedia,
      );
      if (context.mounted) {
        AppToast.success(context, 'Activity updated.');
      }
    } catch (error) {
      if (context.mounted) {
        AppToast.error(context, 'Could not update activity.');
      }
    }
  }

  Future<PendingActivityMedia?> _pickEditMediaFromLibrary() async {
    final picker = ImagePicker();
    final file = await picker.pickMedia(
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (file == null) return null;
    return PendingActivityMedia(file: file, type: _inferMediaType(file));
  }

  Future<PendingActivityMedia?> _takeEditPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (file == null) return null;
    return PendingActivityMedia(file: file, type: ActivityMediaType.photo);
  }

  Future<PendingActivityMedia?> _takeEditVideo() async {
    final file = await ImagePicker().pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 2),
    );
    if (file == null) return null;
    return PendingActivityMedia(file: file, type: ActivityMediaType.video);
  }

  ActivityMediaType _inferMediaType(XFile file) {
    final mime = file.mimeType?.toLowerCase();
    if (mime != null && mime.startsWith('video/')) {
      return ActivityMediaType.video;
    }
    final lowerName = file.name.toLowerCase();
    if (lowerName.endsWith('.mp4') ||
        lowerName.endsWith('.mov') ||
        lowerName.endsWith('.m4v')) {
      return ActivityMediaType.video;
    }
    return ActivityMediaType.photo;
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final service = mutationService ?? ActivityMutationService();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Activity?'),
        content: const Text('This removes the activity post only.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await service.deleteActivity(activity);
      if (context.mounted) Navigator.of(context).pop();
    } catch (error) {
      if (context.mounted) {
        AppToast.error(context, 'Could not delete activity.');
      }
    }
  }
}

class _EditableMediaTile extends StatelessWidget {
  const _EditableMediaTile({
    required this.isVideo,
    required this.onRemove,
    this.url,
    this.file,
  });

  final bool isVideo;
  final String? url;
  final File? file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = this.file;
    final url = this.url;
    return Container(
      width: 84,
      margin: const EdgeInsets.only(right: 10),
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
              child: isVideo
                  ? Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : file != null
                  ? Image.file(file, fit: BoxFit.cover)
                  : url != null && url.isNotEmpty
                  ? Image.network(url, fit: BoxFit.cover)
                  : const Center(child: Icon(Icons.photo_outlined)),
            ),
          ),
          if (isVideo)
            const Positioned(
              left: 8,
              bottom: 8,
              child: Icon(Icons.videocam, color: Colors.white, size: 18),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton.filledTonal(
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 16),
            ),
          ),
        ],
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
          label: 'Glaze',
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
                  ? 'Glaze'
                  : (count == 1 ? '1 Glaze' : '$count Glaze');
              return _DetailAction(
                icon: hasKudos
                    ? Icons.thumb_up_alt_rounded
                    : Icons.thumb_up_alt_outlined,
                label: label,
                active: hasKudos,
                onTap: () {
                  if (uid == activity.ownerId) {
                    ActivityGlazersSheet.show(
                      context: context,
                      activityId: activity.id,
                      kudosService: service,
                    );
                    return;
                  }
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
