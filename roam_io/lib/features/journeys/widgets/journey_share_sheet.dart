/*
 * Author: Amarprit Singh
 * Last Updated: 29 August 2026
 * Description:
 *   Share Journey bottom sheet: previews the shareable card over each
 *   background and exports the chosen one as a PNG. The card's numbers come
 *   from the sharer's own journey document when they can read it, and from
 *   the activity post itself otherwise.
 */

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../../activity_feed/models/activity_feed_item.dart';
import '../data/journey_service.dart';
import '../domain/journey.dart';
import '../domain/journey_share_details.dart';
import 'journey_share_card.dart';

class JourneyShareSheet extends StatefulWidget {
  const JourneyShareSheet({super.key, required this.details});

  final JourneyShareDetails details;

  static Future<void> show({
    required BuildContext context,
    required Journey journey,
  }) {
    return showDetails(
      context: context,
      details: JourneyShareDetails.fromJourney(journey),
    );
  }

  static Future<void> showDetails({
    required BuildContext context,
    required JourneyShareDetails details,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JourneyShareSheet(details: details),
    );
  }

  static Future<void> shareFromActivity(
    BuildContext context,
    ActivityFeedItem activity, {
    String? currentUserId,
    JourneyService? journeyService,
  }) async {
    final details = await resolveShareDetails(
      activity,
      currentUserId: currentUserId,
      journeyService: journeyService,
    );

    if (!context.mounted) return;
    await showDetails(context: context, details: details);
  }

  /// The card's data for [activity].
  ///
  /// The journey document holds the distance recorded live while tracking, so
  /// it is preferred — but only its owner may read it, and the post carries
  /// everything else the card needs, so anyone else shares straight from the
  /// post rather than not at all.
  @visibleForTesting
  static Future<JourneyShareDetails> resolveShareDetails(
    ActivityFeedItem activity, {
    String? currentUserId,
    JourneyService? journeyService,
  }) async {
    final sourceJourneyId = activity.sourceJourneyId ?? '';
    if (sourceJourneyId.isEmpty || currentUserId != activity.ownerId) {
      return JourneyShareDetails.fromActivity(activity);
    }

    try {
      final journey = await (journeyService ?? JourneyService()).getJourneyById(
        userId: activity.ownerId,
        journeyId: sourceJourneyId,
      );
      // The map picture lives on the post, not the journey document, so it
      // has to be carried across or the card falls back to a bare polyline.
      if (journey != null) {
        return JourneyShareDetails.fromJourney(
          journey,
          mapImageUrl: activity.mapImageUrl,
        );
      }
    } catch (error) {
      debugPrint(
        '[JourneyShareSheet] journey load failed '
        'activityId=${activity.id} error=$error',
      );
    }

    return JourneyShareDetails.fromActivity(activity);
  }

  @override
  State<JourneyShareSheet> createState() => _JourneyShareSheetState();
}

class _JourneyShareSheetState extends State<JourneyShareSheet> {
  late final List<GlobalKey> _cardKeys;
  late final PageController _pageController;
  int _currentIndex = 0;
  bool _isSharing = false;
  bool _isMapImageReady = false;
  bool _mapImageRequested = false;

  final List<Color> _backgroundOptions = [
    AppColors.sage,
    AppColors.ink,
    AppColors.clay,
  ];

  @override
  void initState() {
    super.initState();
    _cardKeys = List.generate(_backgroundOptions.length, (_) => GlobalKey());
    _pageController = PageController();
    // Nothing to wait for when the card draws the route itself.
    _isMapImageReady = !widget.details.hasMapImage;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isMapImageReady || _mapImageRequested) return;
    _mapImageRequested = true;
    unawaited(_precacheMapImage());
  }

  /// Loads the post's map picture before the card can be captured.
  ///
  /// A network image that has not decoded yet paints nothing, so sharing
  /// early would export a card with a blank square where the map belongs.
  Future<void> _precacheMapImage() async {
    try {
      await precacheImage(NetworkImage(widget.details.mapImageUrl!), context);
    } catch (error) {
      // The card falls back to the drawn route, so it is still worth sharing.
      debugPrint('[JourneyShareSheet] map image load failed error=$error');
    }
    if (mounted) setState(() => _isMapImageReady = true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _shareImage() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      // Small delay to ensure the UI is fully rendered before capture
      await Future.delayed(const Duration(milliseconds: 50));

      final boundary =
          _cardKeys[_currentIndex].currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/journey_share.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      final xFile = XFile(file.path, mimeType: 'image/png');
      await SharePlus.instance.share(
        ShareParams(text: 'Check out my journey on Roam.io!', files: [xFile]),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.95,
      ),
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppSurfaces.textSubtle(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 48), // Balance close button
                Text(
                  'Share Journey',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Share Card Preview
                      AspectRatio(
                        aspectRatio: 9 / 16,
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) =>
                              setState(() => _currentIndex = index),
                          itemCount: _backgroundOptions.length,
                          itemBuilder: (context, index) {
                            return RepaintBoundary(
                              key: _cardKeys[index],
                              child: JourneyShareCard(
                                details: widget.details,
                                backgroundColor: _backgroundOptions[index],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Background Selector
                      Text(
                        'Background Color',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _backgroundOptions.map((color) {
                          final index = _backgroundOptions.indexOf(color);
                          final isSelected = index == _currentIndex;
                          return GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(
                                        color: color == Colors.white
                                            ? AppColors.ink
                                            : Colors.white,
                                        width: 3,
                                      )
                                    : (color == Colors.white
                                          ? Border.all(color: Colors.grey[300]!)
                                          : null),
                                boxShadow: [
                                  if (isSelected)
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _isSharing || !_isMapImageReady
                      ? null
                      : _shareImage,
                  icon: _isSharing || !_isMapImageReady
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.share),
                  label: Text(
                    !_isMapImageReady
                        ? 'Preparing map...'
                        : _isSharing
                        ? 'Preparing...'
                        : 'Share',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.sage,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
