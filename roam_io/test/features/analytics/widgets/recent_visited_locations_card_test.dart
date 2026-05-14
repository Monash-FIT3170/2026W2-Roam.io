/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Widget tests for RecentVisitedLocationsCard list, empty state, and XP label.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/analytics/widgets/recent_visited_locations_card.dart';
import 'package:roam_io/features/map/data/visit.dart';
import 'package:roam_io/features/profile/domain/xp_reward_config.dart';

void main() {
  testWidgets('shows visit rows with flat visit XP label', (tester) async {
    final visit = Visit(
      placeId: 99,
      googlePlaceId: 'gid',
      placeName: 'Test Park',
      regionId: 'sa2',
      category: 'nature',
      visitedAt: DateTime(2026, 5, 10, 14, 30),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecentVisitedLocationsCard(
            visitsStream: Stream<List<Visit>>.value(<Visit>[visit]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Park'), findsOneWidget);
    expect(find.text('+${XpRewardConfig.visitXpReward} XP'), findsOneWidget);
    expect(find.text('10/05/2026 2:30 PM'), findsOneWidget);
  });

  testWidgets('shows friendly empty state when no visits', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecentVisitedLocationsCard(
            visitsStream: Stream<List<Visit>>.value(<Visit>[]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No visits yet'), findsOneWidget);
  });
}
