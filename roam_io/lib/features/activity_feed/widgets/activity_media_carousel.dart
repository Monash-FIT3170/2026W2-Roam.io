/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 22 August 2026
 * Description:
 *   Shared non-autoplay activity media carousel for feed cards, detail pages,
 *   and profile media gallery entry points.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';
import '../data/activity_map_image.dart';
import '../models/activity_media_item.dart';

/// Swipeable activity media preview.
class ActivityMediaCarousel extends StatefulWidget {
  const ActivityMediaCarousel({
    super.key,
    required this.media,
    this.aspectRatio = ActivityMapImage.aspectRatio,
    this.onTap,
    this.routeSlide,
    this.routeFirst = false,
  });

  final List<ActivityMediaItem> media;

  /// Shape of every slide. Defaults to the map picture's own shape so the route
  /// slide fills the frame rather than sitting in bands, and photos share that
  /// shape so swiping between them does not resize the card.
  final double aspectRatio;
  final ValueChanged<int>? onTap;
  final Widget? routeSlide;
  final bool routeFirst;

  @override
  State<ActivityMediaCarousel> createState() => _ActivityMediaCarouselState();
}

class _ActivityMediaCarouselState extends State<ActivityMediaCarousel> {
  final _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routeSlide = widget.routeSlide;
    final itemCount = widget.media.length + (routeSlide == null ? 0 : 1);
    if (itemCount == 0) return const SizedBox.shrink();

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(color: AppSurfaces.softCard(context)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: itemCount,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) {
                  final mediaIndex = _mediaIndexForPage(index);
                  if (mediaIndex == null) return routeSlide!;
                  return _ActivityMediaFrame(
                    media: widget.media[mediaIndex],
                    onTap: widget.onTap == null
                        ? null
                        : () => widget.onTap!(mediaIndex),
                  );
                },
              ),
              if (itemCount > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < itemCount; i += 1)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: i == _index ? 18 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(
                              alpha: i == _index ? 0.95 : 0.55,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  int? _mediaIndexForPage(int pageIndex) {
    if (widget.routeSlide == null) return pageIndex;
    if (widget.routeFirst) {
      if (pageIndex == 0) return null;
      return pageIndex - 1;
    }
    if (pageIndex == widget.media.length) return null;
    return pageIndex;
  }
}

class _ActivityMediaFrame extends StatelessWidget {
  const _ActivityMediaFrame({required this.media, this.onTap});

  final ActivityMediaItem media;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      fit: StackFit.expand,
      children: [
        if (media.isVideo && (media.thumbnailUrl ?? '').isEmpty)
          ColoredBox(
            color: AppSurfaces.textPrimary(context).withValues(alpha: 0.12),
            child: Icon(
              Icons.videocam_outlined,
              size: 52,
              color: AppSurfaces.textMuted(context),
            ),
          )
        else
          Image.network(
            media.thumbnailUrl?.isNotEmpty == true
                ? media.thumbnailUrl!
                : media.url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => ColoredBox(
              color: AppSurfaces.textPrimary(context).withValues(alpha: 0.08),
              child: Icon(
                Icons.broken_image_outlined,
                color: AppSurfaces.textMuted(context),
              ),
            ),
          ),
        if (media.isVideo)
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.42),
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
          ),
      ],
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
