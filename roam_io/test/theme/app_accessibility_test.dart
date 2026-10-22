/*
 * Description:
 *   Tests the accessibility layer: high-contrast palette ratios (WCAG 2.2 AA),
 *   the Larger Text scaler, the Reduce Motion helpers, and AppAccessibility.wrap.
 */

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/theme/app_accessibility.dart';
import 'package:roam_io/theme/app_colours.dart';
import 'package:roam_io/theme/app_surfaces.dart';
import 'package:roam_io/theme/app_theme.dart';

double _ratio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  group('high-contrast themes', () {
    final themes = {
      'light': AppTheme.highContrastLightTheme,
      'dark': AppTheme.highContrastDarkTheme,
    };

    for (final entry in themes.entries) {
      final name = entry.key;
      final theme = entry.value;
      final scheme = theme.colorScheme;
      final background = theme.scaffoldBackgroundColor;

      test('$name theme is marked high contrast', () {
        expect(theme.extension<HighContrastExtension>(), isNotNull);
      });

      test('$name text, buttons and UI components meet WCAG 2.2 AA', () {
        expect(_ratio(scheme.onSurface, background), greaterThanOrEqualTo(7));
        expect(
          _ratio(scheme.onSurface, scheme.surface),
          greaterThanOrEqualTo(7),
        );
        expect(
          _ratio(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _ratio(scheme.onSecondary, scheme.secondary),
          greaterThanOrEqualTo(4.5),
        );
        expect(_ratio(scheme.primary, background), greaterThanOrEqualTo(4.5));
        expect(_ratio(scheme.outline, background), greaterThanOrEqualTo(3));
        expect(_ratio(scheme.outline, scheme.surface), greaterThanOrEqualTo(3));
      });

      test('$name text theme has no low-contrast greys', () {
        for (final style in [
          theme.textTheme.bodySmall,
          theme.textTheme.bodyMedium,
          theme.textTheme.labelMedium,
          theme.textTheme.titleMedium,
        ]) {
          expect(
            _ratio(style!.color!, background),
            greaterThanOrEqualTo(4.5),
            reason: '$name ${style.fontSize}pt text',
          );
        }
      });

      testWidgets('$name muted and subtle text still reach 4.5:1', (
        tester,
      ) async {
        late Color muted;
        late Color subtle;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                muted = AppSurfaces.textMuted(context);
                subtle = AppSurfaces.textSubtle(context);
                return const SizedBox();
              },
            ),
          ),
        );

        expect(
          _ratio(Color.alphaBlend(muted, background), background),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _ratio(Color.alphaBlend(subtle, background), background),
          greaterThanOrEqualTo(4.5),
        );
      });
    }

    test('standard themes are untouched and unmarked', () {
      expect(AppTheme.lightTheme.extension<HighContrastExtension>(), isNull);
      expect(AppTheme.darkTheme.extension<HighContrastExtension>(), isNull);
      expect(AppTheme.lightTheme.colorScheme.primary, AppColors.sage);
      expect(AppTheme.darkTheme.colorScheme.primary, AppColors.sage);
    });

    test('standard themes pad small controls to a 48dp target', () {
      expect(
        AppTheme.lightTheme.materialTapTargetSize,
        MaterialTapTargetSize.padded,
      );
      expect(
        AppTheme.darkTheme.materialTapTargetSize,
        MaterialTapTargetSize.padded,
      );
    });

    testWidgets('surfaces switch to solid borders when high contrast', (
      tester,
    ) async {
      late Color standardBorder;
      late Color hcBorder;
      Widget probe(ThemeData theme, void Function(Color) onBorder) {
        return MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              onBorder(AppSurfaces.border(context));
              return const SizedBox();
            },
          ),
        );
      }

      await tester.pumpWidget(
        probe(AppTheme.lightTheme, (c) => standardBorder = c),
      );
      await tester.pumpWidget(
        probe(AppTheme.highContrastLightTheme, (c) => hcBorder = c),
      );
      await tester.pumpAndSettle();

      expect(standardBorder.a, lessThan(0.5));
      expect(hcBorder.a, 1.0);
      expect(
        _ratio(
          hcBorder,
          AppTheme.highContrastLightTheme.scaffoldBackgroundColor,
        ),
        greaterThanOrEqualTo(3),
      );
    });
  });

  group('accent foreground helpers', () {
    Future<List<Color>> read(WidgetTester tester, ThemeData theme) async {
      late List<Color> colors;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          themeAnimationDuration: Duration.zero,
          home: Builder(
            builder: (context) {
              colors = [
                context.sageForeground,
                context.clayForeground,
                context.lightSageForeground,
              ];
              return const SizedBox();
            },
          ),
        ),
      );
      return colors;
    }

    testWidgets('are exactly the old colours outside high contrast', (
      tester,
    ) async {
      expect(await read(tester, AppTheme.lightTheme), [
        AppColors.sage,
        AppColors.clay,
        AppColors.lightSage,
      ]);
      expect(await read(tester, AppTheme.darkTheme), [
        AppColors.sage,
        AppColors.clay,
        AppColors.lightSage,
      ]);
    });

    testWidgets('use AA theme colours in high contrast', (tester) async {
      for (final theme in [
        AppTheme.highContrastLightTheme,
        AppTheme.highContrastDarkTheme,
      ]) {
        final colors = await read(tester, theme);
        final bg = theme.scaffoldBackgroundColor;
        for (final colour in colors) {
          expect(_ratio(colour, bg), greaterThanOrEqualTo(4.5));
        }
      }
    });
  });

  group('Larger Text scaler', () {
    test('boosts the system scale by the configured factor', () {
      final scaler = AppAccessibility.largerText(TextScaler.noScaling);
      expect(scaler.scale(10), closeTo(12, 1e-9));
      expect(scaler.scale(20), closeTo(24, 1e-9));
    });

    test('composes with the system text scale', () {
      final scaler = AppAccessibility.largerText(const TextScaler.linear(1.5));
      expect(scaler.scale(10), closeTo(18, 1e-9));
    });

    test('is capped so layouts stay usable', () {
      final scaler = AppAccessibility.largerText(const TextScaler.linear(2.0));
      expect(scaler.scale(10), closeTo(20, 1e-9));
    });

    test('never shrinks text below the system scale', () {
      final huge = AppAccessibility.largerText(const TextScaler.linear(3.0));
      expect(huge.scale(10), closeTo(30, 1e-9));
    });

    test('is equal when wrapping an equal base', () {
      expect(
        AppAccessibility.largerText(const TextScaler.linear(1.2)),
        AppAccessibility.largerText(const TextScaler.linear(1.2)),
      );
    });
  });

  group('AppAccessibility.wrap', () {
    Future<void> pumpWrapped(
      WidgetTester tester, {
      required bool largerText,
      bool disableAnimations = false,
      TextScaler systemScaler = TextScaler.noScaling,
      required void Function(BuildContext) onBuild,
    }) {
      return tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            textScaler: systemScaler,
            disableAnimations: disableAnimations,
          ),
          child: MaterialApp(
            builder: (context, child) =>
                AppAccessibility.wrap(context, child, largerText: largerText),
            home: Builder(
              builder: (context) {
                onBuild(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    }

    testWidgets('leaves text alone when Larger Text is off', (tester) async {
      late TextScaler scaler;
      await pumpWrapped(
        tester,
        largerText: false,
        systemScaler: const TextScaler.linear(1.3),
        onBuild: (c) => scaler = MediaQuery.textScalerOf(c),
      );
      expect(scaler.scale(10), closeTo(13, 1e-9));
    });

    testWidgets('multiplies the system scale when Larger Text is on', (
      tester,
    ) async {
      late TextScaler scaler;
      await pumpWrapped(
        tester,
        largerText: true,
        systemScaler: const TextScaler.linear(1.3),
        onBuild: (c) => scaler = MediaQuery.textScalerOf(c),
      );
      expect(scaler.scale(10), closeTo(15.6, 1e-9));
    });

    testWidgets('cuts page transitions when Reduce Motion is on', (
      tester,
    ) async {
      late PageTransitionsTheme transitions;
      await pumpWrapped(
        tester,
        largerText: false,
        disableAnimations: true,
        onBuild: (c) => transitions = Theme.of(c).pageTransitionsTheme,
      );
      expect(transitions, AppAccessibility.noTransitions);
    });

    testWidgets('keeps default page transitions otherwise', (tester) async {
      late PageTransitionsTheme transitions;
      await pumpWrapped(
        tester,
        largerText: false,
        onBuild: (c) => transitions = Theme.of(c).pageTransitionsTheme,
      );
      expect(transitions, isNot(AppAccessibility.noTransitions));
    });
  });

  group('Reduce Motion helpers', () {
    testWidgets('reduceMotion mirrors MediaQuery.disableAnimations', (
      tester,
    ) async {
      final seen = <bool>[];
      Widget app(bool disable) => MediaQuery(
        data: MediaQueryData(disableAnimations: disable),
        child: Builder(
          builder: (context) {
            seen.add(context.reduceMotion);
            return const SizedBox();
          },
        ),
      );

      await tester.pumpWidget(app(false));
      await tester.pumpWidget(app(true));
      expect(seen, [false, true]);
    });

    testWidgets('motionDuration collapses to zero when reduced', (
      tester,
    ) async {
      Duration? normal;
      Duration? reduced;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Builder(
            builder: (context) {
              normal = context.motionDuration(const Duration(seconds: 1));
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              reduced = context.motionDuration(const Duration(seconds: 1));
              return const SizedBox();
            },
          ),
        ),
      );
      expect(normal, const Duration(seconds: 1));
      expect(reduced, Duration.zero);
    });

    testWidgets('loopUnlessReduced loops, parks, and resumes', (tester) async {
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(seconds: 1),
      );

      controller.loopUnlessReduced(reduce: false);
      expect(controller.isAnimating, isTrue);

      // Repeated calls while looping must not restart the animation.
      await tester.pump(const Duration(milliseconds: 400));
      final before = controller.value;
      controller.loopUnlessReduced(reduce: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.value, greaterThan(before));

      controller.loopUnlessReduced(reduce: true, restAt: 0.5);
      expect(controller.isAnimating, isFalse);
      expect(controller.value, 0.5);

      controller.loopUnlessReduced(reduce: false);
      expect(controller.isAnimating, isTrue);
      controller.dispose();
    });
  });
}
