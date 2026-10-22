/*
 * Description:
 *   Larger Text, High Contrast and 48dp tap-target checks for shared chrome:
 *   bottom navigation, glass map controls, headers and map overlays.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/data/map_page.dart';
import 'package:roam_io/features/map/domain/exploration_overlay_style.dart';
import 'package:roam_io/features/map/widgets/heatmap_legend.dart';
import 'package:roam_io/features/map/widgets/mode_toggle_chip.dart';
import 'package:roam_io/features/map/widgets/place_marker_legend.dart';
import 'package:roam_io/shared/widgets/app_bottom_nav_bar.dart';
import 'package:roam_io/shared/widgets/activity_saved_celebration.dart';
import 'package:roam_io/shared/widgets/app_page_header.dart';
import 'package:roam_io/shared/widgets/app_toast.dart';
import 'package:roam_io/shared/widgets/liquid_glass.dart';
import 'package:roam_io/theme/app_cartoon.dart';
import 'package:roam_io/theme/app_theme.dart';

import '../../support/accessibility_harness.dart';

Widget _pushed(Widget Function(BuildContext) builder) {
  return Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (c) => Scaffold(body: builder(c))),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
}

void main() {
  group('bottom navigation', () {
    testAccessibleLayouts('lays out without overflow', (
      tester,
      theme,
      scale,
    ) async {
      await pumpAccessible(
        tester,
        Scaffold(
          bottomNavigationBar: AppBottomNavBar(
            currentIndex: 2,
            youUnreadCount: 120,
            onTap: (_) {},
          ),
        ),
        theme: theme,
        textScale: scale,
        largerText: true,
      );
    });

    testWidgets('every tab and the floating MAP button are >= 48dp', (
      tester,
    ) async {
      await pumpAccessible(
        tester,
        Scaffold(
          bottomNavigationBar: AppBottomNavBar(currentIndex: 0, onTap: (_) {}),
        ),
        theme: AppTheme.lightTheme,
      );

      for (final label in ['HOME', 'SOCIAL', 'YOU', 'SETTINGS', 'MAP']) {
        final target = find.ancestor(
          of: find.text(label),
          matching: find.byType(GestureDetector),
        );
        final size = tester.getSize(target.first);
        expect(size.width, greaterThanOrEqualTo(48), reason: label);
        expect(size.height, greaterThanOrEqualTo(48), reason: label);
      }
    });
  });

  group('tap targets', () {
    testWidgets('LiquidGlassIconButton is at least 48x48', (tester) async {
      await pumpAccessible(
        tester,
        Scaffold(
          body: Center(
            child: LiquidGlassIconButton(
              icon: Icons.add,
              onPressed: () {},
              tooltip: 'Add',
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byType(LiquidGlassIconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('CartoonIconButton is at least 48x48', (tester) async {
      await pumpAccessible(
        tester,
        Scaffold(
          body: Center(
            child: CartoonIconButton(
              icon: Icons.add,
              tooltip: 'Add',
              onPressed: () {},
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    for (final header in <String, Widget Function()>{
      'CartoonPageHeader': () => const CartoonPageHeader(title: 'Title'),
      'AppPageHeader': () => const AppPageHeader(title: 'Title'),
    }.entries) {
      testWidgets('${header.key} back button is at least 48x48', (
        tester,
      ) async {
        await pumpAccessible(tester, _pushed((_) => header.value()));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final size = tester.getSize(find.byType(BackButton));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      });
    }

    testWidgets('map location controls are at least 48x48', (tester) async {
      await pumpAccessible(
        tester,
        Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: MapLocationControls(
              onReportHazard: () {},
              onRecenter: () {},
            ),
          ),
        ),
      );
      for (final key in ['report_hazard_button', 'recenter_map_button']) {
        final size = tester.getSize(find.byKey(ValueKey(key)));
        expect(size.width, greaterThanOrEqualTo(48), reason: key);
        expect(size.height, greaterThanOrEqualTo(48), reason: key);
      }
    });
  });

  group('map chrome', () {
    final widgets = <String, Widget Function(ThemeData)>{
      'MapLocationControls': (_) =>
          MapLocationControls(onReportHazard: () {}, onRecenter: () {}),
      'PlaceMarkerLegendButton': (_) => const PlaceMarkerLegendButton(),
      'StartJourneyChip': (_) => StartJourneyChip(onPressed: () {}),
      'HeatmapLegend': (theme) => HeatmapLegend(
        style: ExplorationOverlayStyle.forBrightness(theme.brightness),
      ),
      'PlaceMarkerLegend': (_) => const PlaceMarkerLegend(),
    };
    for (final entry in widgets.entries) {
      testAccessibleLayouts('${entry.key} lays out', (
        tester,
        theme,
        scale,
      ) async {
        await pumpAccessible(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: Center(child: entry.value(theme)),
            ),
          ),
          theme: theme,
          textScale: scale,
          largerText: true,
        );
      });
    }

    testWidgets('glass controls are opaque and outlined in high contrast', (
      tester,
    ) async {
      await pumpAccessible(
        tester,
        Scaffold(
          body: Center(
            child: LiquidGlassIconButton(icon: Icons.add, onPressed: () {}),
          ),
        ),
        theme: AppTheme.highContrastLightTheme,
      );
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(LiquidGlass),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.color!.a, 1.0);
      expect((decoration.border as Border).top.width, greaterThanOrEqualTo(2));
    });
  });

  group('feedback surfaces', () {
    testAccessibleLayouts('toast lays out', (tester, theme, scale) async {
      await pumpAccessible(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => AppToast.success(
                context,
                'Your visit to the riverside gardens was logged',
                subtitle: '+50 XP for exploring a brand new tile today',
              ),
              child: const Text('Show'),
            ),
          ),
        ),
        theme: theme,
        textScale: scale,
        largerText: true,
      );
      await tester.tap(find.text('Show'));
      await tester.pump(const Duration(milliseconds: 300));
    });

    testAccessibleLayouts('activity saved celebration lays out', (
      tester,
      theme,
      scale,
    ) async {
      await pumpAccessible(
        tester,
        ActivitySavedCelebration(xpEarned: 120, onDismiss: () {}),
        theme: theme,
        textScale: scale,
        largerText: true,
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('celebration skips the particle burst with Reduce Motion', (
      tester,
    ) async {
      await pumpAccessible(
        tester,
        ActivitySavedCelebration(xpEarned: 120, onDismiss: () {}),
        theme: AppTheme.lightTheme,
        disableAnimations: true,
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Activity Saved'), findsWidgets);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter.runtimeType.toString() == '_SavedParticlePainter',
        ),
        findsNothing,
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });
  });
}
