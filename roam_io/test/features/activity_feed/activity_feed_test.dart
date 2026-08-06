/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Widget tests for ActivityFeedCard and ActivityDetailScreen — centred
 *   metrics, live comment counts, privacy engagement flags, and personal
 *   detail without engagement controls.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/activity_feed/data/stub_activity_feed_data.dart';
import 'package:roam_io/features/activity_feed/models/activity_comment.dart';
import 'package:roam_io/features/activity_feed/screens/activity_detail_screen.dart';
import 'package:roam_io/features/activity_feed/widgets/activity_feed_card.dart';
import 'package:roam_io/features/activity_feed/widgets/activity_map_preview.dart';

void main() {
  testWidgets('personal stub card shows journey metrics and map preview', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final activity = StubActivityFeedData.personalJourney;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ActivityFeedCard.fromItem(
              activity,
              showKudos: true,
              showComments: true,
              showShare: true,
              commentCountStream: Stream<int>.value(0),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Journey to Coles'), findsOneWidget);
    expect(find.text('August 3, 2026 at 10:07 AM'), findsOneWidget);
    expect(find.text('47m 51s'), findsOneWidget);
    expect(find.text('Locations Visited'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('+200 XP'), findsOneWidget);
    expect(find.text('Map preview'), findsOneWidget);
    expect(find.byType(ActivityMapPreview), findsOneWidget);
    expect(find.text('Kudos'), findsOneWidget);
    expect(find.text('0 comments'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    // Full labels — no ellipsis clipping on the three-action row.
    expect(find.textContaining('…'), findsNothing);
    expect(find.textContaining('...'), findsNothing);
    expect(find.text('Morning Weight Training'), findsNothing);
    expect(find.byIcon(Icons.fitness_center), findsNothing);

    final label = tester.widget<Text>(find.text('Locations Visited'));
    expect(label.maxLines, 1);
    expect(label.softWrap, isFalse);
    expect(label.textAlign, TextAlign.center);
  });

  testWidgets('sidequest stub uses Locations Visited and comment counts', (
    tester,
  ) async {
    final amar = StubActivityFeedData.friendActivities.firstWhere(
      (item) => item.displayName == 'Amar',
    );
    final counts = StreamController<int>.broadcast();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ActivityFeedCard.fromItem(
              amar,
              showShare: false,
              commentCountStream: counts.stream,
            ),
          ),
        ),
      ),
    );
    counts.add(0);
    await tester.pumpAndSettle();

    expect(find.text('Sidequest Progress'), findsNothing);
    expect(find.text('Locations Visited'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Share'), findsNothing);
    expect(find.text('Kudos'), findsOneWidget);
    expect(find.text('0 comments'), findsOneWidget);

    counts.add(1);
    await tester.pumpAndSettle();
    expect(find.text('1 comment'), findsOneWidget);

    counts.add(2);
    await tester.pumpAndSettle();
    expect(find.text('2 comments'), findsOneWidget);

    await counts.close();
  });

  testWidgets('formatCommentCount uses singular and plural forms', (
    tester,
  ) async {
    expect(formatCommentCount(0), '0 comments');
    expect(formatCommentCount(1), '1 comment');
    expect(formatCommentCount(2), '2 comments');
  });

  testWidgets(
    'detail screen shows expanded map and metrics without engagement',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final activity = StubActivityFeedData.personalJourney;

      await tester.pumpWidget(
        MaterialApp(home: ActivityDetailScreen(activity: activity)),
      );

      expect(find.text('Journey to Coles'), findsOneWidget);
      expect(find.text('August 3, 2026 at 10:07 AM'), findsOneWidget);
      expect(find.text('Journey route map'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('47m 51s'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('47m 51s'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('+200 XP'), findsOneWidget);
      expect(find.text('Kudos'), findsNothing);
      expect(find.text('Comment'), findsNothing);
      expect(find.text('0 comments'), findsNothing);
      expect(find.text('Share'), findsNothing);
    },
  );
}
