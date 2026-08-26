/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 22 August 2026
 * Description:
 *   Profile media gallery derived from visible activity media rather than a
 *   separate gallery collection.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';
import '../../map/widgets/media_viewer.dart';
import '../data/activity_mutation_service.dart';
import '../models/activity_feed_item.dart';
import 'activity_detail_screen.dart';

/// Media gallery for one profile's visible activities.
class ActivityMediaGalleryScreen extends StatefulWidget {
  const ActivityMediaGalleryScreen({
    super.key,
    required this.profileId,
    this.currentUserId,
    this.mutationService,
  });

  final String profileId;
  final String? currentUserId;
  final ActivityMutationService? mutationService;

  @override
  State<ActivityMediaGalleryScreen> createState() =>
      _ActivityMediaGalleryScreenState();
}

class _ActivityMediaGalleryScreenState
    extends State<ActivityMediaGalleryScreen> {
  bool _grid = true;

  @override
  Widget build(BuildContext context) {
    final service = widget.mutationService ?? ActivityMutationService();
    return Scaffold(
      backgroundColor: AppSurfaces.pageBackground(context),
      appBar: AppBar(
        backgroundColor: AppSurfaces.pageBackground(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Activity Media'),
        actions: [
          IconButton(
            tooltip: _grid ? 'List view' : 'Grid view',
            onPressed: () => setState(() => _grid = !_grid),
            icon: Icon(_grid ? Icons.view_list_rounded : Icons.grid_view),
          ),
        ],
      ),
      body: StreamBuilder<List<ProfileActivityMediaEntry>>(
        stream: service.watchProfileActivityMedia(widget.profileId),
        builder: (context, snapshot) {
          final entries = snapshot.data ?? const <ProfileActivityMediaEntry>[];
          if (snapshot.connectionState == ConnectionState.waiting &&
              entries.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (entries.isEmpty) {
            return Center(
              child: Text(
                'No activity media yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppSurfaces.textMuted(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }
          return _grid
              ? GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (context, index) => _GalleryTile(
                    entry: entries[index],
                    onTap: () {
                      _openViewer(context, entries, index);
                    },
                    onActivityTap: () {
                      _openActivity(context, entries[index]);
                    },
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _GalleryListRow(
                    entry: entries[index],
                    onTap: () => _openViewer(context, entries, index),
                    onActivityTap: () => _openActivity(context, entries[index]),
                  ),
                );
        },
      ),
    );
  }

  void _openViewer(
    BuildContext context,
    List<ProfileActivityMediaEntry> entries,
    int index,
  ) {
    MediaViewer.show(
      context: context,
      mediaUrls: entries.map((entry) => entry.media.url).toList(),
      initialIndex: index,
    );
  }

  void _openActivity(BuildContext context, ProfileActivityMediaEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActivityDetailScreen(
          activity: entry.activity,
          currentUserId: widget.currentUserId,
          showEngagementActions: true,
          showShare: true,
        ),
      ),
    );
  }
}

class _GalleryListRow extends StatelessWidget {
  const _GalleryListRow({
    required this.entry,
    required this.onTap,
    required this.onActivityTap,
  });

  final ProfileActivityMediaEntry entry;
  final VoidCallback onTap;
  final VoidCallback onActivityTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      tileColor: AppSurfaces.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: SizedBox.square(
        dimension: 56,
        child: _GalleryPreview(entry: entry),
      ),
      title: Text(
        entry.activity.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: AppSurfaces.textPrimary(context),
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        _formatActivityDateTime(context, entry.activity),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Activity options',
        icon: const Icon(Icons.more_horiz_rounded),
        onSelected: (value) {
          if (value == 'activity') onActivityTap();
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'activity', child: Text('Open activity')),
        ],
      ),
      onTap: onTap,
    );
  }

  String _formatActivityDateTime(
    BuildContext context,
    ActivityFeedItem activity,
  ) {
    final createdAt = activity.createdAt;
    if (createdAt == null) return activity.timestampLabel;
    final local = createdAt.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(local);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return '$date · $time';
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.entry,
    required this.onTap,
    required this.onActivityTap,
  });

  final ProfileActivityMediaEntry entry;
  final VoidCallback onTap;
  final VoidCallback onActivityTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          InkWell(
            onTap: onTap,
            child: _GalleryPreview(entry: entry),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton.filledTonal(
              tooltip: 'Open activity',
              visualDensity: VisualDensity.compact,
              onPressed: onActivityTap,
              icon: const Icon(Icons.more_horiz_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryPreview extends StatelessWidget {
  const _GalleryPreview({required this.entry});

  final ProfileActivityMediaEntry entry;

  @override
  Widget build(BuildContext context) {
    final media = entry.media;
    return Stack(
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
          ),
        if (media.isVideo)
          const Center(
            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 34),
          ),
      ],
    );
  }
}
