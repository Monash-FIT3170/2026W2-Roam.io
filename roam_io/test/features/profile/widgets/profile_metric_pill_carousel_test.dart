/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Widget tests for profile metric pill carousel clipping behaviour.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/data/visit.dart';
import 'package:roam_io/features/profile/domain/visited_polygon_record.dart';
import 'package:roam_io/features/profile/domain/xp_event.dart';
import 'package:roam_io/features/profile/widgets/profile_dashboard.dart';

void main() {
  testWidgets(
    'metric pill carousel uses Clip.none so capsules keep rounded edges',
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
      expect(scrollable.clipBehavior, Clip.none);

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
