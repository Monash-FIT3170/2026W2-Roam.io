import 'package:flutter/material.dart';

import '../../../theme/app_colours.dart';

/// Visual values used by explored-region, current-region, and heat-map overlays.
///
/// The light and dark definitions deliberately preserve the current appearance.
/// Dark-specific tuning belongs in the follow-up visual commit.
@immutable
class ExplorationOverlayStyle {
  const ExplorationOverlayStyle._({
    required this.exploredRegionFillColor,
    required this.currentRegionFillColor,
    required this.unexploredRegionFillColor,
    required this.regionStrokeColor,
    required this.regionStrokeWidth,
    required this.exploredBoundaryColor,
    required this.exploredBoundaryWidth,
    required this.heatmapColdColor,
    required this.heatmapWarmColor,
    required this.heatmapHotColor,
    required this.heatmapFillOpacity,
  });

  static const Color _exploredRegionFillColor = Color(0x30FFFFFF);
  static const Color _currentRegionFillColor = Color(0x30FFFFFF);
  static const Color _unexploredRegionFillColor = Color(0x00000000);
  static const Color _regionStrokeColor = Color(0x00000000);

  static const Color _heatmapColdColor = Color(0xFFFFF176);
  static const Color _heatmapWarmColor = Color(0xFFFFC247);
  static const Color _heatmapHotColor = Color(0xFFE53935);

  static const ExplorationOverlayStyle light = ExplorationOverlayStyle._(
    exploredRegionFillColor: _exploredRegionFillColor,
    currentRegionFillColor: _currentRegionFillColor,
    unexploredRegionFillColor: _unexploredRegionFillColor,
    regionStrokeColor: _regionStrokeColor,
    regionStrokeWidth: 0,
    exploredBoundaryColor: AppColors.sage,
    exploredBoundaryWidth: 3,
    heatmapColdColor: _heatmapColdColor,
    heatmapWarmColor: _heatmapWarmColor,
    heatmapHotColor: _heatmapHotColor,
    heatmapFillOpacity: 0.6,
  );

  static const ExplorationOverlayStyle dark = ExplorationOverlayStyle._(
    exploredRegionFillColor: _exploredRegionFillColor,
    currentRegionFillColor: _currentRegionFillColor,
    unexploredRegionFillColor: _unexploredRegionFillColor,
    regionStrokeColor: _regionStrokeColor,
    regionStrokeWidth: 0,
    exploredBoundaryColor: AppColors.lightSage,
    exploredBoundaryWidth: 3,
    heatmapColdColor: _heatmapColdColor,
    heatmapWarmColor: _heatmapWarmColor,
    heatmapHotColor: _heatmapHotColor,
    heatmapFillOpacity: 0.6,
  );

  static ExplorationOverlayStyle forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  final Color exploredRegionFillColor;
  final Color currentRegionFillColor;
  final Color unexploredRegionFillColor;
  final Color regionStrokeColor;
  final int regionStrokeWidth;
  final Color exploredBoundaryColor;
  final int exploredBoundaryWidth;
  final Color heatmapColdColor;
  final Color heatmapWarmColor;
  final Color heatmapHotColor;
  final double heatmapFillOpacity;

  Color heatmapColorForIntensity(double intensity) {
    final clampedIntensity = intensity.clamp(0.0, 1.0).toDouble();

    if (clampedIntensity <= 0.5) {
      return Color.lerp(
        heatmapColdColor,
        heatmapWarmColor,
        clampedIntensity * 2,
      )!;
    }

    return Color.lerp(
      heatmapWarmColor,
      heatmapHotColor,
      (clampedIntensity - 0.5) * 2,
    )!;
  }

  Color heatmapFillColorForIntensity(double intensity) {
    return heatmapColorForIntensity(
      intensity,
    ).withValues(alpha: heatmapFillOpacity);
  }
}
