import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../../activity_feed/models/activity_feed_item.dart';
import '../data/journey_service.dart';
import '../domain/journey.dart';
import '../domain/journey_location.dart';
import '../domain/transport_mode.dart';
import 'journey_share_card.dart';

class JourneyShareSheet extends StatefulWidget {
  const JourneyShareSheet({super.key, required this.journey});

  final Journey journey;

  static Future<void> show({
    required BuildContext context,
    required Journey journey,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JourneyShareSheet(journey: journey),
    );
  }

  static Future<void> shareFromActivity(
      BuildContext context, ActivityFeedItem activity) async {
    try {
      final journeyService = JourneyService();
      Journey? journey = await journeyService.getJourneyById(
          userId: activity.ownerId, journeyId: activity.id);

      if (journey == null) {
        // Fallback for test activities or missing journeys: create a mock journey
        int durationSeconds = 1800; // default 30 min
        double distanceMeters = 5000; // default 5km
        int xpEarned = 150;
        
        for (final metric in activity.metrics) {
          final val = metric.value.toLowerCase();
          if (metric.label.toLowerCase() == 'time') {
            int mins = 0;
            int secs = 0;
            final mMatch = RegExp(r'(\d+)m').firstMatch(val);
            if (mMatch != null) mins = int.tryParse(mMatch.group(1) ?? '0') ?? 0;
            final sMatch = RegExp(r'(\d+)s').firstMatch(val);
            if (sMatch != null) secs = int.tryParse(sMatch.group(1) ?? '0') ?? 0;
            if (mins > 0 || secs > 0) durationSeconds = mins * 60 + secs;
          } else if (metric.label.toLowerCase() == 'xp gained') {
            final xMatch = RegExp(r'(\d+)').firstMatch(val);
            if (xMatch != null) xpEarned = int.tryParse(xMatch.group(1) ?? '0') ?? 0;
          }
        }

        journey = Journey(
          id: activity.id,
          userId: activity.ownerId,
          startTime: DateTime.now().subtract(Duration(seconds: durationSeconds)),
          endTime: DateTime.now(),
          startLocation: const JourneyLocation(latLng: LatLng(-37.8136, 144.9631), displayName: 'Start Location'),
          endLocation: const JourneyLocation(latLng: LatLng(-37.8140, 144.9640), displayName: 'End Location'),
          transportMode: TransportMode.walk,
          encodedRoute: '', // Blank route for test activities
          distanceMeters: distanceMeters,
          durationSeconds: durationSeconds,
          xpEarned: xpEarned,
          journeyXpEarned: xpEarned,
          tilesUnlocked: 0,
          tileXpEarned: 0,
        );
      }

      if (context.mounted) {
        show(context: context, journey: journey);
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(
            context, 'Failed to load journey for sharing.');
      }
    }
  }

  @override
  State<JourneyShareSheet> createState() => _JourneyShareSheetState();
}

class _JourneyShareSheetState extends State<JourneyShareSheet> {
  late final List<GlobalKey> _cardKeys;
  late final PageController _pageController;
  int _currentIndex = 0;
  bool _isSharing = false;

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
      
      final boundary = _cardKeys[_currentIndex].currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/journey_share.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      final xFile = XFile(file.path, mimeType: 'image/png');
      await SharePlus.instance.share(
        ShareParams(
          text: 'Check out my journey on Roam.io!',
          files: [xFile],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Share Card Preview
                      AspectRatio(
                        aspectRatio: 9 / 16,
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) => setState(() => _currentIndex = index),
                          itemCount: _backgroundOptions.length,
                          itemBuilder: (context, index) {
                            return RepaintBoundary(
                              key: _cardKeys[index],
                              child: JourneyShareCard(
                                journey: widget.journey,
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
                              margin: const EdgeInsets.symmetric(horizontal: 12),
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
                                    )
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
                  onPressed: _isSharing ? null : _shareImage,
                  icon: _isSharing
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
                    _isSharing ? 'Preparing...' : 'Share',
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
