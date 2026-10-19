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
      expect(style.heatmapFillOpacity, 0.55);
    });

    test('keeps both palettes visible and translucent over the map', () {
      for (final style in <ExplorationOverlayStyle>[
        ExplorationOverlayStyle.light,
        ExplorationOverlayStyle.dark,
      ]) {
        expect(
          style.exploredRegionFillColor,
          isNot(style.unexploredRegionFillColor),
        );
        expect(
          style.currentRegionFillColor,
          isNot(style.unexploredRegionFillColor),
        );
        expect(
          style.exploredRegionFillColor.a,
          allOf(greaterThan(0), lessThan(1)),
        );
        expect(
          style.currentRegionFillColor.a,
          allOf(greaterThan(0), lessThan(1)),
        );
        expect(style.unexploredRegionFillColor.a, 0);
        expect(style.regionStrokeColor.a, 0);
        expect(style.heatmapFillOpacity, lessThan(1));
      }
    });

    for (final testCase in <({String name, ExplorationOverlayStyle style})>[
      (name: 'light', style: ExplorationOverlayStyle.light),
      (name: 'dark', style: ExplorationOverlayStyle.dark),
    ]) {
      test(
        'maps, interpolates, and clamps ${testCase.name} heatmap intensity',
        () {
          final style = testCase.style;

          expect(style.heatmapColorForIntensity(-1), style.heatmapColdColor);
          expect(style.heatmapColorForIntensity(0), style.heatmapColdColor);
          expect(
            style.heatmapColorForIntensity(0.25),
            Color.lerp(style.heatmapColdColor, style.heatmapWarmColor, 0.5),
          );
          expect(style.heatmapColorForIntensity(0.5), style.heatmapWarmColor);
          expect(
            style.heatmapColorForIntensity(0.75),
            Color.lerp(style.heatmapWarmColor, style.heatmapHotColor, 0.5),
          );
          expect(style.heatmapColorForIntensity(1), style.heatmapHotColor);
          expect(style.heatmapColorForIntensity(2), style.heatmapHotColor);

          for (final intensity in <double>[-1, 0, 0.25, 0.5, 0.75, 1, 2]) {
            final gradientColor = style.heatmapColorForIntensity(intensity);
            final fillColor = style.heatmapFillColorForIntensity(intensity);

            expect(
              fillColor,
              gradientColor.withValues(alpha: style.heatmapFillOpacity),
            );
            expect(fillColor.a, closeTo(style.heatmapFillOpacity, 0.001));
            expect(fillColor.a, lessThan(1));
          }
        },
      );
    }
  });
}
