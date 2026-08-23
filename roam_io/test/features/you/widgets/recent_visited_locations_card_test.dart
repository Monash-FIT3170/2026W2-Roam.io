/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Widget tests for RecentVisitedLocationsCard: shrink-wrap height, max five
 *   rows, empty state, and visit XP labels. Guards against Scaffold extendBody
 *   MediaQuery padding inflating ListView-backed cards.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/you/widgets/recent_visited_locations_card.dart';
import 'package:roam_io/features/map/data/visit.dart';
import 'package:roam_io/features/profile/domain/xp_reward_config.dart';
import 'package:roam_io/shared/widgets/app_bottom_nav_bar.dart';

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
          body: RecentVisitedLocationsCard(visits: <Visit>[visit]),
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
      const MaterialApp(
        home: Scaffold(body: RecentVisitedLocationsCard(visits: <Visit>[])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No visits yet'), findsOneWidget);
  });

  testWidgets('caps displayed visits to five', (tester) async {
    final visits = List<Visit>.generate(
      7,
      (index) => Visit(
        placeId: index,
        googlePlaceId: 'g$index',
        placeName: 'Place $index',
        regionId: 'r$index',
        category: 'nature',
        visitedAt: DateTime(2026, 8, 6, 10, index),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecentVisitedLocationsCard(visits: visits)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Place 0'), findsOneWidget);
    expect(find.text('Place 4'), findsOneWidget);
    expect(find.text('Place 5'), findsNothing);
    expect(find.text('Place 6'), findsNothing);
  });

  testWidgets(
    'shrink-wraps five visit rows without extendBody MediaQuery pad',
    (tester) async {
      final visits = List<Visit>.generate(
        5,
        (index) => Visit(
          placeId: index,
          googlePlaceId: 'g$index',
          placeName: 'Visit $index',
          regionId: 'r$index',
          category: 'nature',
          visitedAt: DateTime(2026, 8, 6, 12, index),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            extendBody: true,
            body: Align(
              alignment: Alignment.topCenter,
              child: RecentVisitedLocationsCard(
                key: const Key('recent-visits-card'),
                visits: visits,
              ),
            ),
            bottomNavigationBar: const SizedBox(
              height: AppBottomNavBar.barHeight,
              child: ColoredBox(color: Colors.black12),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardSize = tester.getSize(
        find.byKey(const Key('recent-visits-card')),
      );

      // Five padded rows + title + separators + card chrome must stay well
      // below content-plus-nav-bar-height (would indicate MediaQuery pad leak).
      expect(cardSize.height, lessThan(480));
      expect(cardSize.height, lessThan(AppBottomNavBar.barHeight + 360));
      expect(cardSize.height, greaterThan(200));
      expect(find.text('Recent visits'), findsOneWidget);
    },
  );
}
