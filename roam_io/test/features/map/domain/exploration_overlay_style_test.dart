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

    test('preserves the existing overlay values', () {
      for (final style in <ExplorationOverlayStyle>[
        ExplorationOverlayStyle.light,
        ExplorationOverlayStyle.dark,
      ]) {
        expect(style.exploredRegionFillColor, const Color(0x30FFFFFF));
        expect(style.currentRegionFillColor, const Color(0x30FFFFFF));
        expect(style.unexploredRegionFillColor, const Color(0x00000000));
        expect(style.regionStrokeColor, const Color(0x00000000));
        expect(style.regionStrokeWidth, 0);
        expect(style.exploredBoundaryWidth, 3);
        expect(style.heatmapFillOpacity, 0.6);
      }

      expect(
        ExplorationOverlayStyle.light.exploredBoundaryColor,
        AppColors.sage,
      );
      expect(
        ExplorationOverlayStyle.dark.exploredBoundaryColor,
        AppColors.lightSage,
      );
    });

    test('maps and clamps heatmap intensity using the existing gradient', () {
      final style = ExplorationOverlayStyle.light;

      expect(style.heatmapColorForIntensity(-1), const Color(0xFFFFF176));
      expect(style.heatmapColorForIntensity(0.5), const Color(0xFFFFC247));
      expect(style.heatmapColorForIntensity(2), const Color(0xFFE53935));
      expect(style.heatmapFillColorForIntensity(0.5).a, closeTo(0.6, 0.001));
    });
  });
}
