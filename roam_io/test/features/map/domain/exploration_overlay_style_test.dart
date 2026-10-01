import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/domain/exploration_overlay_style.dart';
import 'package:roam_io/theme/app_colours.dart';

void main() {
  group('ExplorationOverlayStyle', () {
    test('resolves the effective style from brightness', () {
      expect(
        ExplorationOverlayStyle.forBrightness(Brightness.light),
        same(ExplorationOverlayStyle.light),
      );
      expect(
        ExplorationOverlayStyle.forBrightness(Brightness.dark),
        same(ExplorationOverlayStyle.dark),
      );
    });

    test('preserves the existing light overlay values', () {
      final style = ExplorationOverlayStyle.light;

      expect(style.exploredRegionFillColor, const Color(0x30FFFFFF));
      expect(style.currentRegionFillColor, const Color(0x30FFFFFF));
      expect(style.unexploredRegionFillColor, const Color(0x00000000));
      expect(style.regionStrokeColor, const Color(0x00000000));
      expect(style.regionStrokeWidth, 0);
      expect(style.exploredBoundaryColor, AppColors.sage);
      expect(style.exploredBoundaryWidth, 3);
      expect(style.heatmapColdColor, const Color(0xFFFFF176));
      expect(style.heatmapWarmColor, const Color(0xFFFFC247));
      expect(style.heatmapHotColor, const Color(0xFFE53935));
      expect(style.heatmapFillOpacity, 0.6);
    });

    test('uses the higher-contrast dark overlay values', () {
      final style = ExplorationOverlayStyle.dark;

      expect(style.exploredRegionFillColor, const Color(0x509EB58D));
      expect(style.currentRegionFillColor, const Color(0x709EB58D));
      expect(style.unexploredRegionFillColor, const Color(0x00000000));
      expect(style.regionStrokeColor, const Color(0x00000000));
      expect(style.regionStrokeWidth, 0);
      expect(style.exploredBoundaryColor, AppColors.lightSage);
      expect(style.exploredBoundaryWidth, 4);
      expect(style.heatmapColdColor, const Color(0xFFFFE066));
      expect(style.heatmapWarmColor, const Color(0xFFFFA23F));
      expect(style.heatmapHotColor, const Color(0xFFFF5A5F));
      expect(style.heatmapFillOpacity, 0.75);
    });

    test('maps and clamps light heatmap intensity using its gradient', () {
      final style = ExplorationOverlayStyle.light;

      expect(style.heatmapColorForIntensity(-1), const Color(0xFFFFF176));
      expect(style.heatmapColorForIntensity(0.5), const Color(0xFFFFC247));
      expect(style.heatmapColorForIntensity(2), const Color(0xFFE53935));
      expect(style.heatmapFillColorForIntensity(0.5).a, closeTo(0.6, 0.001));
    });

    test('maps and clamps dark heatmap intensity using its gradient', () {
      final style = ExplorationOverlayStyle.dark;

      expect(style.heatmapColorForIntensity(-1), const Color(0xFFFFE066));
      expect(style.heatmapColorForIntensity(0.5), const Color(0xFFFFA23F));
      expect(style.heatmapColorForIntensity(2), const Color(0xFFFF5A5F));
      expect(style.heatmapFillColorForIntensity(0.5).a, closeTo(0.75, 0.001));
    });
  });
}
