import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../theme/app_colours.dart';
import '../../map/domain/map_styles.dart';

/// A shared scaffold for authentication pages with a custom animated cloud background.
class AuthPageScaffold extends StatelessWidget {
  const AuthPageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footerText,
    this.footerLabel,
    this.onFooterTap,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String? footerText;
  final String? footerLabel;
  final VoidCallback? onFooterTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          const Positioned.fill(child: CloudAuthBackground()),
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  const Spacer(),
                  // Main content at the bottom
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: textTheme.headlineMedium?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          subtitle,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.ink.withValues(alpha: 0.7),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        child,
                        if (footerText != null &&
                            footerLabel != null &&
                            onFooterTap != null) ...[
                          const SizedBox(height: 24),
                          Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 4,
                              children: [
                                Text(
                                  footerText!,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: AppColors.ink.withValues(alpha: 0.7),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: onFooterTap,
                                  child: Text(
                                    footerLabel!,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: AppColors.sage,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Background with dense, seamless drifting clouds and soft cutouts.
class CloudAuthBackground extends StatefulWidget {
  const CloudAuthBackground({super.key});

  @override
  State<CloudAuthBackground> createState() => _CloudAuthBackgroundState();
}

class _CloudAuthBackgroundState extends State<CloudAuthBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    );
    bool isTest = false;
    assert(() {
      try {
        isTest = Platform.environment.containsKey('FLUTTER_TEST');
      } catch (_) {}
      return true;
    }());
    // Oscillate to prevent noticeable seams or bounds
    if (!isTest) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;

        // Cloud Layers
        final Widget clouds = Stack(
          fit: StackFit.expand,
          children: [
            _buildCloudLayer(
              image: 'assets/fog_of_war/cartoon_cloud_01.png',
              progress: progress,
              speedX: 100,
              speedY: 50,
              opacity: 0.9,
              scale: 0.6,
            ),
            _buildCloudLayer(
              image: 'assets/fog_of_war/cartoon_cloud_01.png',
              progress: progress,
              speedX: -80,
              speedY: 40,
              opacity: 0.6,
              scale: 0.8,
            ),
          ],
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            // Static Map Background centered at Monash University Clayton
            GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(-37.9105, 145.1362),
                zoom: 16.0,
              ),
              style: MapStyles.forBrightness(Theme.of(context).brightness),
              zoomControlsEnabled: false,
              scrollGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
              myLocationEnabled: false,
            ),
            clouds,
          ],
        );
      },
    );
  }

  Widget _buildCloudLayer({
    required String image,
    required double progress,
    required double speedX,
    required double speedY,
    required double opacity,
    required double scale,
  }) {
    // We create an oversized bounding box so we can translate the texture
    // without exposing the edges, allowing a natural pan.
    const double extraSize =
        800; // Enough padding to prevent edges showing during pan

    // Smooth easing for translation
    final dx = (progress - 0.5) * speedX;
    final dy = (progress - 0.5) * speedY;

    return Positioned(
      top: -extraSize / 2 + dy,
      left: -extraSize / 2 + dx,
      right: -extraSize / 2 - dx,
      bottom: -extraSize / 2 - dy,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Image.asset(
            image,
            repeat: ImageRepeat
                .repeat, // Tile at natural resolution to prevent blurry stretching
            filterQuality: FilterQuality.low,
          ),
        ),
      ),
    );
  }
}
