/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 29 August 2026 — Sanjevan Rajasegar
 * Description:
 *   Widget tests for shared profile metric pill selector clipping and
 *   selection behaviour.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/data/visit.dart';
import 'package:roam_io/features/profile/domain/visited_polygon_record.dart';
import 'package:roam_io/features/profile/domain/xp_event.dart';
import 'package:roam_io/features/profile/widgets/profile_dashboard.dart';
import 'package:roam_io/features/profile/widgets/profile_metric_pill_selector.dart';

void main() {
  testWidgets(
    'shared metric pill selector scrolls horizontally and updates selection',
    (tester) async {
      var selectedIndex = 0;
      const labels = ['Locations', 'Tiles', 'Journeys', 'XP'];
      const itemKeys = [
        'stats-category-locations',
        'stats-category-tiles',
        'stats-category-journeys',
        'stats-category-xp',
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 180,
                    child: ProfileMetricPillSelector(
                      labels: labels,
                      itemKeys: itemKeys,
                      selectedIndex: selectedIndex,
                      onSelected: (index) {
                        setState(() => selectedIndex = index);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = tester.widget<SingleChildScrollView>(
        find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
      );
      expect(scrollable.scrollDirection, Axis.horizontal);

      final carouselCard = tester.widget<Container>(
        find.ancestor(
          of: find.byWidget(scrollable),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.clipBehavior == Clip.antiAlias &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).borderRadius ==
                    BorderRadius.circular(18),
          ),
        ),
      );
      expect(carouselCard.clipBehavior, Clip.antiAlias);

      final xpKey = find.byKey(const ValueKey<String>('stats-category-xp'));
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(-120, 0),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(xpKey);
      await tester.pumpAndSettle();
      await tester.tap(xpKey);
      await tester.pumpAndSettle();

      expect(selectedIndex, 3);
      final selectedPillMaterial = tester.widget<Material>(
        find.descendant(of: xpKey, matching: find.byType(Material)).first,
      );
      expect(selectedPillMaterial.borderRadius, BorderRadius.circular(999));
    },
  );

  testWidgets(
    'metric pill carousel clips to outer card and keeps capsule pills',
    (tester) async {
      var selected = ProfileGraphMetric.locationsVisited;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 220,
                    child: ProfileMetricLineGraphSection(
                      visits: const <Visit>[],
                      tileRecords: const <VisitedPolygonRecord>[],
                      xpEvents: const <XpEvent>[],
                      selectedMetric: selected,
                      onMetricSelected: (metric) {
                        setState(() => selected = metric);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = tester.widget<SingleChildScrollView>(
        find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
      );
      final carouselCard = tester.widget<Container>(
        find.ancestor(
          of: find.byWidget(scrollable),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.clipBehavior == Clip.antiAlias &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).borderRadius ==
                    BorderRadius.circular(18),
          ),
        ),
      );
      expect(carouselCard.clipBehavior, Clip.antiAlias);

      // Scroll so a later pill is only partially inside the narrow viewport.
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(-80, 0),
      );
      await tester.pumpAndSettle();

      final tilesKey = find.byKey(
        const ValueKey<String>('profile-metric-tilesUnlocked'),
      );
      await tester.ensureVisible(tilesKey);
      await tester.pumpAndSettle();
      await tester.tap(tilesKey);
      await tester.pumpAndSettle();
      expect(selected, ProfileGraphMetric.tilesUnlocked);

      final selectedPillMaterial = tester.widget<Material>(
        find.descendant(of: tilesKey, matching: find.byType(Material)).first,
      );
      expect(selectedPillMaterial.borderRadius, BorderRadius.circular(999));
    },
  );
}
