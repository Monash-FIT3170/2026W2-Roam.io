/*
 * Author: Amarprit Singh
 * Last Updated: 5 October 2026
 * Description:
 *   One-row photo gallery preview for the Profile tab: a "Photos" heading
 *   and the latest four photos from the traveller's journeys, the last
 *   carrying a "+N" for the rest. Hidden entirely until there is a photo.
 */

import 'package:flutter/material.dart';

import '../../../../theme/app_surfaces.dart';
import '../../../activity_feed/models/activity_media_item.dart';
import 'stat_block.dart';

class ProfilePhotoStrip extends StatelessWidget {
  const ProfilePhotoStrip({
    super.key,
    required this.media,
    required this.onOpenGallery,
    required this.onOpenPhoto,
    this.moreAvailable = false,
  });

  /// Newest first.
  final List<ActivityMediaItem> media;

  /// Opens the full gallery.
  final VoidCallback onOpenGallery;

  /// Opens one photo full screen, by its index in [media].
  final ValueChanged<int> onOpenPhoto;

  /// The feed only loads the latest posts, so a full page may be hiding
  /// older photos beyond [media].
  final bool moreAvailable;

  static const int _columns = 4;
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final shown = media.take(_columns).toList(growable: false);
    final hiddenCount = media.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          hint: 'Opens all photos',
          child: InkWell(
            onTap: onOpenGallery,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    'Photos',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppSurfaces.textPrimary(context),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${media.length}${moreAvailable ? '+' : ''}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppSurfaces.textMuted(context),
                      fontWeight: FontWeight.w600,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppSurfaces.textMuted(context),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var index = 0; index < _columns; index++) ...[
              if (index > 0) const SizedBox(width: _gap),
              Expanded(
                child: index < shown.length
                    ? _PhotoTile(
                        media: shown[index],
                        // The last tile stands for everything not shown.
                        moreCount: index == _columns - 1 ? hiddenCount : 0,
                        onTap: index == _columns - 1 && hiddenCount > 0
                            ? onOpenGallery
                            : () => onOpenPhoto(index),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.media,
    required this.moreCount,
    required this.onTap,
  });

  final ActivityMediaItem media;
  final int moreCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final placeholder = AppSurfaces.textPrimary(
      context,
    ).withValues(alpha: 0.08);
    final thumbnail = media.thumbnailUrl;
    final source = thumbnail != null && thumbnail.isNotEmpty
        ? thumbnail
        : (media.isVideo ? null : media.url);

    return Semantics(
      button: true,
      label: moreCount > 0
          ? 'Show all photos, $moreCount more'
          : (media.isVideo ? 'Open video' : 'Open photo'),
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Material(
            color: placeholder,
            child: InkWell(
              onTap: onTap,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Decoded near tile size rather than at full resolution, so
                  // four thumbnails never cost four full photos of memory.
                  // Twice the tile's width keeps a landscape photo tall enough
                  // to fill the square without being stretched.
                  final cacheWidth =
                      (constraints.maxWidth *
                              MediaQuery.devicePixelRatioOf(context) *
                              2)
                          .round();
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (source == null)
                        Icon(
                          Icons.videocam_outlined,
                          color: AppSurfaces.textMuted(context),
                        )
                      else
                        Ink.image(
                          image: ResizeImage.resizeIfNeeded(
                            cacheWidth > 0 ? cacheWidth : null,
                            null,
                            NetworkImage(source),
                          ),
                          fit: BoxFit.cover,
                          onImageError: (_, _) {},
                        ),
                      if (media.isVideo && moreCount == 0)
                        const Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      if (moreCount > 0)
                        ColoredBox(
                          color: Colors.black.withValues(alpha: 0.45),
                          child: Center(
                            child: Text(
                              '+$moreCount',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: kTabularFigures,
                                  ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
