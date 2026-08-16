/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Regression tests for You screen tabs, profile identity XP progress,
 *   full-width social/exploration stats, metric line graphs, activities stub
 *   (Kudos + comments + Share on the card; no engagement on detail), and
 *   location states.
 */

import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/activity_feed/data/comment_service.dart';
import 'package:roam_io/features/activity_feed/models/activity_comment.dart';
import 'package:roam_io/features/activity_feed/screens/comments_screen.dart';
import 'package:roam_io/features/you/screens/you_screen.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/journeys/data/journey_service.dart';
import 'package:roam_io/features/map/data/visit.dart';
import 'package:roam_io/features/map/data/visit_service.dart';
import 'package:roam_io/features/map/data/visited_region_service.dart';
import 'package:roam_io/features/map/domain/visit_event.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';
import 'package:roam_io/features/profile/domain/visited_polygon_meta.dart';
import 'package:roam_io/features/profile/domain/visited_polygon_record.dart';
import 'package:roam_io/features/profile/domain/xp_event.dart';
import 'package:roam_io/features/you/services/home_base_service.dart';
import 'package:roam_io/features/you/services/stats_summary_service.dart';
import 'package:roam_io/features/you/milestones/milestone_service.dart';

YouScreen _testYouScreen({
  required VisitService visitService,
  required VisitedRegionService visitedRegionService,
  Stream<List<XpEvent>>? xpEventsStream,
  CommentService? commentService,
}) {
  final firestore = FakeFirebaseFirestore();
  return YouScreen(
    visitService: visitService,
    visitedRegionService: visitedRegionService,
    journeyService: JourneyService(firestore: firestore),
    statsSummaryService: StatsSummaryService(firestore: firestore),
    homeBaseService: HomeBaseService(firestore: firestore),
    milestoneService: MilestoneService(firestore: firestore),
    xpEventsStream: xpEventsStream,
    commentService: commentService,
  );
}

Future<void> _openStatsTab(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Stats'));
  await tester.tap(find.text('Stats'));
  await tester.pumpAndSettle();
}

Future<void> _openStatsCategory(WidgetTester tester, String label) async {
  await _openStatsTab(tester);
  final categoryTab = find.descendant(
    of: find.byType(TabBar).last,
    matching: find.text(label),
  );
  await tester.ensureVisible(categoryTab);
  await tester.tap(categoryTab);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows current profile XP instead of placeholder XP', (
    tester,
  ) async {
    final provider = AuthProvider(
      authRepository: _FakeAuthRepository(_buildProfile(xp: 12345)),
    );
    await provider.refreshCurrentUser();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: _testYouScreen(
              visitService: _FakeVisitService(totalVisitCount: 0),
              visitedRegionService: _FakeVisitedRegionService(<String>{}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('You'), findsNothing);
    expect(find.text('Summary'), findsNothing);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Activities'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);
    expect(find.text('Milestones'), findsOneWidget);
    expect(find.text('XP Count'), findsNothing);
    expect(
      find.text('Level ${ProfileModel.levelFromXp(12345)}'),
      findsOneWidget,
    );
    expect(find.text('Locations Visited'), findsNothing);
    expect(find.text('Tiles Unlocked'), findsNothing);
    expect(find.text('Visit volume by week'), findsNothing);
    expect(find.text('Total Visits'), findsNothing);
    expect(find.text('2,450'), findsNothing);

    provider.dispose();
  });

  testWidgets('shows total visited tile count from all visited regions', (
    tester,
  ) async {
    final provider = AuthProvider(
      authRepository: _FakeAuthRepository(_buildProfile(xp: 50)),
    );
    await provider.refreshCurrentUser();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: _testYouScreen(
              visitService: _FakeVisitService(totalVisitCount: 9),
              visitedRegionService: _FakeVisitedRegionService(<String>{
                'region-1',
                'region-2',
                'region-3',
                'region-4',
                'region-5',
                'region-6',
              }),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Traveller'), findsOneWidget);
    expect(find.text('@traveller'), findsOneWidget);
    expect(find.text('Tiles'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Followers'), findsOneWidget);
    expect(find.text('Journeys'), findsOneWidget);
    expect(find.text('Sidequests'), findsOneWidget);
    expect(find.text('6'), findsWidgets);
    expect(find.text('48'), findsNothing);

    provider.dispose();
  });

  testWidgets('removes old visit and XP dashboard cards', (tester) async {
    final provider = AuthProvider(
      authRepository: _FakeAuthRepository(_buildProfile(xp: 50)),
    );
    await provider.refreshCurrentUser();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: _testYouScreen(
              visitService: _FakeVisitService(totalVisitCount: 14),
              visitedRegionService: _FakeVisitedRegionService(<String>{
                'tile-a',
                'tile-b',
                'tile-c',
              }),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tiles Visited'), findsNothing);
    expect(find.text('Total Visits'), findsNothing);
    expect(find.text('XP Count'), findsNothing);
    expect(find.text('Visits'), findsNothing);
    expect(find.text('This Week'), findsNothing);
    expect(find.text('3'), findsWidgets);
    expect(find.text('156'), findsNothing);

    provider.dispose();
  });

  testWidgets('Stats tab shows location visit chart for repeated visits', (
    tester,
  ) async {
    final provider = AuthProvider(
      authRepository: _FakeAuthRepository(_buildProfile(xp: 75)),
    );
    await provider.refreshCurrentUser();

    final visits = <Visit>[
      Visit(
        placeId: 1,
        googlePlaceId: 'g-1',
        placeName: 'Lakeside Cafe',
        regionId: 'region-a',
        category: 'food_drink',
        visitedAt: DateTime(2026, 5, 10, 10),
      ),
      Visit(
        placeId: 2,
        googlePlaceId: 'g-2',
        placeName: 'City Park',
        regionId: 'region-b',
        category: 'nature',
        visitedAt: DateTime(2026, 5, 12, 12),
      ),
      Visit(
        placeId: 1,
        googlePlaceId: 'g-1',
        placeName: 'Lakeside Cafe',
        regionId: 'region-a',
        category: 'food_drink',
        visitedAt: DateTime(2026, 5, 15, 15),
      ),
    ];

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: _testYouScreen(
              visitService: _FakeVisitService(
                totalVisitCount: 3,
                allVisits: visits,
              ),
              visitedRegionService: _FakeVisitedRegionService(<String>{
                'region-a',
                'region-b',
              }),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _openStatsTab(tester);

    expect(find.text('Total visits'), findsOneWidget);
    expect(find.text('Top category'), findsOneWidget);
    expect(find.text('Visit streak'), findsOneWidget);
    expect(find.text('Visits by week'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    provider.dispose();
  });

  testWidgets('Stats tab shows empty location chart when no visits', (
    tester,
  ) async {
    final provider = AuthProvider(
      authRepository: _FakeAuthRepository(_buildProfile(xp: 75)),
    );
    await provider.refreshCurrentUser();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: _testYouScreen(
              visitService: _FakeVisitService(
                totalVisitCount: 0,
                allVisits: const <Visit>[],
              ),
              visitedRegionService: _FakeVisitedRegionService(<String>{}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _openStatsTab(tester);
    expect(find.text('No locations to chart yet'), findsOneWidget);

    provider.dispose();
  });

  testWidgets(
    'updates profile and stats data automatically when streamed data changes',
    (tester) async {
      final provider = AuthProvider(
        authRepository: _FakeAuthRepository(_buildProfile(xp: 75)),
      );
      await provider.refreshCurrentUser();

      final visitService = _FakeVisitService(
        totalVisitCount: 0,
        allVisits: const <Visit>[],
      );
      final visitedRegionService = _FakeVisitedRegionService(<String>{});

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: _testYouScreen(
                visitService: visitService,
                visitedRegionService: visitedRegionService,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0'), findsWidgets);

      visitService.emitAllVisits(<Visit>[
        Visit(
          placeId: 1,
          googlePlaceId: 'g-1',
          placeName: 'Lakeside Cafe',
          regionId: 'region-a',
          category: 'food_drink',
          visitedAt: DateTime(2026, 5, 10, 10),
        ),
        Visit(
          placeId: 1,
          googlePlaceId: 'g-1',
          placeName: 'Lakeside Cafe',
          regionId: 'region-a',
          category: 'food_drink',
          visitedAt: DateTime(2026, 5, 11, 10),
        ),
      ]);
      visitedRegionService.emitVisitedRegionIds(<String>{
        'region-a',
        'region-b',
      });
      await tester.pumpAndSettle();

      expect(find.text('2'), findsWidgets);

      await _openStatsTab(tester);
      expect(find.text('Visits by week'), findsOneWidget);

      await visitService.dispose();
      await visitedRegionService.dispose();
      provider.dispose();
    },
  );

  testWidgets('opens Activities tab and shows placeholder activity card', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = AuthProvider(
      authRepository: _FakeAuthRepository(_buildProfile(xp: 75)),
    );
    await provider.refreshCurrentUser();
    final comments = _FakeYouCommentService();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: _testYouScreen(
              visitService: _FakeVisitService(totalVisitCount: 0),
              visitedRegionService: _FakeVisitedRegionService(<String>{}),
              commentService: comments,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activities'));
    await tester.pumpAndSettle();
    expect(find.text('No activities yet'), findsNothing);
    expect(find.text('Journey to Coles'), findsOneWidget);
    expect(find.text('August 3, 2026 at 10:07 AM'), findsOneWidget);
    expect(find.text('47m 51s'), findsOneWidget);
    expect(find.text('Locations Visited'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('+200 XP'), findsOneWidget);
    expect(find.text('Map preview'), findsOneWidget);
    expect(find.text('Morning Weight Training'), findsNothing);
    expect(find.text('Traveller'), findsOneWidget);
    expect(find.text('Kudos'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('0 comments'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Journey to Coles'), findsOneWidget);
    expect(find.text('Journey route map'), findsOneWidget);
    expect(find.text('Kudos'), findsNothing);
    expect(find.text('Comment'), findsNothing);
    expect(find.text('0 comments'), findsNothing);
    expect(find.text('Share'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Personal card still exposes Kudos + Comments + Share after detail pop.
    expect(find.text('0 comments'), findsOneWidget);
    expect(find.text('Kudos'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);

    await tester.ensureVisible(find.text('0 comments'));
    await tester.tap(find.text('0 comments'));
    await tester.pumpAndSettle();
    expect(find.byType(CommentsScreen), findsOneWidget);
    expect(find.text('No comments yet'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Traveller'), findsOneWidget);

    await comments.dispose();
    provider.dispose();
  });

  testWidgets('Activities Comment posts and updates personal card count', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = AuthProvider(
      authRepository: _FakeAuthRepository(_buildProfile(xp: 75)),
    );
    await provider.refreshCurrentUser();
    final comments = _FakeYouCommentService();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: _testYouScreen(
              visitService: _FakeVisitService(totalVisitCount: 0),
              visitedRegionService: _FakeVisitedRegionService(<String>{}),
              commentService: comments,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activities'));
    await tester.pumpAndSettle();
    expect(find.text('Kudos'), findsOneWidget);
    expect(find.text('0 comments'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);

    await tester.ensureVisible(find.text('0 comments'));
    await tester.tap(find.text('0 comments'));
    await tester.pumpAndSettle();
    expect(find.byType(CommentsScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Looks great');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Send'));
    await tester.pumpAndSettle();
    expect(find.text('Looks great'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1 comment'), findsOneWidget);
    expect(find.text('Kudos'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);

    await comments.dispose();
    provider.dispose();
  });

  testWidgets(
    'Stats XP tab shows empty state when history is empty',
    (tester) async {
      final provider = AuthProvider(
        authRepository: _FakeAuthRepository(_buildProfile(xp: 75)),
      );
      await provider.refreshCurrentUser();

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: _testYouScreen(
                visitService: _FakeVisitService(totalVisitCount: 3),
                visitedRegionService: _FakeVisitedRegionService(<String>{
                  'tile-a',
                  'tile-b',
                }),
                xpEventsStream: Stream<List<XpEvent>>.value(const <XpEvent>[]),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _openStatsCategory(tester, 'XP');

      expect(find.text('No XP gained yet this period'), findsOneWidget);

      provider.dispose();
    },
  );

  testWidgets('Stats XP chart updates when new XP events arrive', (
    tester,
  ) async {
    final provider = AuthProvider(
      authRepository: _FakeAuthRepository(_buildProfile(xp: 75)),
    );
    await provider.refreshCurrentUser();

    final xpController = StreamController<List<XpEvent>>.broadcast();
    final weekStart = _mondayOnOrBefore(DateTime(2026, 8, 5));

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: _testYouScreen(
              visitService: _FakeVisitService(totalVisitCount: 0),
              visitedRegionService: _FakeVisitedRegionService(<String>{}),
              xpEventsStream: xpController.stream,
            ),
          ),
        ),
      ),
    );
    xpController.add(const <XpEvent>[]);
    await tester.pumpAndSettle();

    await _openStatsCategory(tester, 'XP');
    expect(find.text('No XP gained yet this period'), findsOneWidget);

    xpController.add(<XpEvent>[
      XpEvent(
        id: 'e1',
        amount: 50,
        earnedAt: weekStart.add(const Duration(days: 1)),
        source: XpEventSource.visit,
      ),
      XpEvent(
        id: 'e2',
        amount: 50,
        earnedAt: weekStart.add(const Duration(days: 2)),
        source: XpEventSource.tileUnlock,
      ),
      XpEvent(
        id: 'e3',
        amount: 50,
        earnedAt: weekStart.subtract(const Duration(days: 7)),
        source: XpEventSource.visit,
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('No XP gained yet this period'), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);

    await xpController.close();
    provider.dispose();
  });

  testWidgets('tapping a stats chart point shows the selected week value', (
    tester,
  ) async {
    final provider = AuthProvider(
      authRepository: _FakeAuthRepository(_buildProfile(xp: 75)),
    );
    await provider.refreshCurrentUser();

    final weekStart = _mondayOnOrBefore(DateTime(2026, 8, 5));
    final visits = <Visit>[
      Visit(
        placeId: 1,
        googlePlaceId: 'g1',
        placeName: 'Cafe A',
        regionId: 'r1',
        category: 'cafe',
        visitedAt: weekStart.add(const Duration(days: 1)),
      ),
      Visit(
        placeId: 2,
        googlePlaceId: 'g2',
        placeName: 'Cafe B',
        regionId: 'r1',
        category: 'cafe',
        visitedAt: weekStart.add(const Duration(days: 2)),
      ),
      Visit(
        placeId: 3,
        googlePlaceId: 'g3',
        placeName: 'Cafe C',
        regionId: 'r1',
        category: 'cafe',
        visitedAt: weekStart.add(const Duration(days: 3)),
      ),
    ];

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: _testYouScreen(
              visitService: _FakeVisitService(
                totalVisitCount: visits.length,
                allVisits: visits,
              ),
              visitedRegionService: _FakeVisitedRegionService(<String>{}),
              xpEventsStream: Stream<List<XpEvent>>.value(const <XpEvent>[]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _openStatsTab(tester);

    final lastPoint = find.byKey(const ValueKey<String>('stats-graph-point-5'));
    expect(lastPoint, findsOneWidget);

    await tester.tap(lastPoint);
    await tester.pumpAndSettle();

    expect(find.textContaining('3 Locations Visited'), findsOneWidget);

    provider.dispose();
  });

  testWidgets('switching stats category resets selected chart point', (
    tester,
  ) async {
    final provider = AuthProvider(
      authRepository: _FakeAuthRepository(_buildProfile(xp: 75)),
    );
    await provider.refreshCurrentUser();

    final weekStart = _mondayOnOrBefore(DateTime(2026, 8, 5));
    final visits = <Visit>[
      Visit(
        placeId: 1,
        googlePlaceId: 'g1',
        placeName: 'Cafe A',
        regionId: 'r1',
        category: 'cafe',
        visitedAt: weekStart.add(const Duration(days: 1)),
      ),
    ];

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: _testYouScreen(
              visitService: _FakeVisitService(
                totalVisitCount: visits.length,
                allVisits: visits,
              ),
              visitedRegionService: _FakeVisitedRegionService(<String>{
                'tile-a',
              }),
              xpEventsStream: Stream<List<XpEvent>>.value(const <XpEvent>[]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _openStatsTab(tester);

    await tester.tap(find.byKey(const ValueKey<String>('stats-graph-point-5')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 Locations Visited'), findsOneWidget);

    await _openStatsCategory(tester, 'Tiles');

    expect(find.textContaining('1 Locations Visited'), findsNothing);

    provider.dispose();
  });

  testWidgets(
    'stats survive Activities detail navigation and stay reactive',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final weekStart = _mondayOnOrBefore(DateTime.now());
      final visits = <Visit>[
        Visit(
          placeId: 1,
          googlePlaceId: 'park-1',
          placeName: 'Persistent Park',
          regionId: 'region-a',
          category: 'nature',
          visitedAt: weekStart.add(const Duration(hours: 3)),
        ),
      ];
      final visitService = _FakeVisitService(
        totalVisitCount: 1,
        allVisits: visits,
      );
      final regionService = _FakeVisitedRegionService(<String>{
        'region-a',
        'region-b',
      });
      final xpController = StreamController<List<XpEvent>>.broadcast();
      final provider = AuthProvider(
        authRepository: _FakeAuthRepository(_buildProfile(xp: 250)),
      );
      await provider.refreshCurrentUser();

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: _testYouScreen(
                visitService: visitService,
                visitedRegionService: regionService,
                xpEventsStream: xpController.stream,
              ),
            ),
          ),
        ),
      );
      xpController.add(<XpEvent>[
        XpEvent(
          id: 'xp-1',
          amount: 40,
          earnedAt: weekStart.add(const Duration(hours: 2)),
          source: XpEventSource.visit,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('Tiles'), findsOneWidget);
      expect(find.text('2'), findsWidgets);

      await _openStatsCategory(tester, 'XP');

      await tester.tap(find.text('Activities'));
      await tester.pumpAndSettle();
      expect(find.text('Journey to Coles'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Journey route map'), findsOneWidget);
      expect(find.text('Kudos'), findsNothing);
      expect(find.text('0 comments'), findsNothing);
      expect(find.text('Share'), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsWidgets);

      visitService.emitAllVisits(<Visit>[
        ...visits,
        Visit(
          placeId: 2,
          googlePlaceId: 'cafe-1',
          placeName: 'Reactive Cafe',
          regionId: 'region-a',
          category: 'food',
          visitedAt: weekStart.add(const Duration(hours: 5)),
        ),
      ]);
      await tester.pumpAndSettle();

      await _openStatsTab(tester);
      expect(find.text('Visits by week'), findsOneWidget);
      expect(find.text('Total visits'), findsOneWidget);
      expect(find.text('Top category'), findsOneWidget);
      expect(find.text('Visit streak'), findsOneWidget);
      expect(find.text('2'), findsWidgets);

      provider.dispose();
      await visitService.dispose();
      await regionService.dispose();
      await xpController.close();
    },
  );
}

DateTime _mondayOnOrBefore(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

ProfileModel _buildProfile({required int xp}) {
  return ProfileModel(
    uid: 'user-1',
    username: 'traveller',
    displayName: 'Traveller',
    email: 'traveller@example.com',
    createdAt: DateTime(2026, 5, 1, 10),
    updatedAt: DateTime(2026, 5, 1, 11),
    xp: xp,
    level: ProfileModel.levelFromXp(xp),
  );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._profile);

  final ProfileModel _profile;
  final _FakeUser _user = _FakeUser(
    uid: 'user-1',
    email: 'traveller@example.com',
  );

  @override
  Stream<firebase_auth.User?> authStateChanges() =>
      Stream<firebase_auth.User?>.value(_user);

  @override
  firebase_auth.User? get currentUser => _user;

  @override
  Future<ProfileModel?> getCurrentUserProfile() async => _profile;

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVisitService implements VisitService {
  _FakeVisitService({required this.totalVisitCount, List<Visit>? allVisits})
    : _allVisits = allVisits ?? _buildVisits(totalVisitCount);

  final int totalVisitCount;
  List<Visit> _allVisits;
  final StreamController<List<Visit>> _allVisitsController =
      StreamController<List<Visit>>.broadcast();

  @override
  Future<int> getVisitCount(String userId) async {
    return totalVisitCount;
  }

  @override
  Future<List<Visit>> getAllVisits(String userId) async {
    return _allVisits;
  }

  @override
  Stream<List<Visit>> watchAllVisits(String userId) {
    return Stream<List<Visit>>.multi((controller) {
      controller.add(_allVisits);
      final subscription = _allVisitsController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Stream<List<Visit>> watchRecentVisits(String userId, {int limit = 5}) {
    return Stream<List<Visit>>.multi((controller) {
      controller.add(_allVisits.take(limit).toList());
      final subscription = _allVisitsController.stream.listen(
        (visits) => controller.add(visits.take(limit).toList()),
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  void emitAllVisits(List<Visit> visits) {
    _allVisits = visits;
    _allVisitsController.add(visits);
  }

  Future<void> dispose() {
    return _allVisitsController.close();
  }

  @override
  Stream<List<VisitEvent>> watchVisitEvents(String userId, {int limit = 100}) {
    return Stream<List<VisitEvent>>.value(const <VisitEvent>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  static List<Visit> _buildVisits(int count) {
    return List<Visit>.generate(
      count,
      (index) => Visit(
        placeId: index,
        googlePlaceId: 'generated-$index',
        placeName: 'Generated Visit $index',
        regionId: 'generated-region',
        category: 'other',
        visitedAt: DateTime(2026, 5, 1).add(Duration(minutes: index)),
      ),
    );
  }
}

class _FakeVisitedRegionService implements VisitedRegionService {
  _FakeVisitedRegionService(Set<String> visitedRegionIds)
    : _visitedRegionIds = visitedRegionIds,
      _visitedPolygonRecords = _recordsFromIds(visitedRegionIds);

  Set<String> _visitedRegionIds;
  List<VisitedPolygonRecord> _visitedPolygonRecords;
  final StreamController<Set<String>> _visitedRegionIdsController =
      StreamController<Set<String>>.broadcast();
  final StreamController<List<VisitedPolygonRecord>>
  _visitedPolygonRecordsController =
      StreamController<List<VisitedPolygonRecord>>.broadcast();

  @override
  Future<Set<String>> loadVisitedRegionIds() async {
    return _visitedRegionIds;
  }

  @override
  Stream<Set<String>> watchVisitedRegionIds() {
    return Stream<Set<String>>.multi((controller) {
      controller.add(_visitedRegionIds);
      final subscription = _visitedRegionIdsController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Stream<List<VisitedPolygonRecord>> watchVisitedPolygonRecords() {
    return Stream<List<VisitedPolygonRecord>>.multi((controller) {
      controller.add(_visitedPolygonRecords);
      final subscription = _visitedPolygonRecordsController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Stream<Map<String, VisitedPolygonMeta>> watchVisitedPolygonMeta() {
    return Stream<Map<String, VisitedPolygonMeta>>.value(
      const <String, VisitedPolygonMeta>{},
    );
  }

  @override
  Stream<Map<String, int>> watchPolygonEntryCounts() {
    return Stream<Map<String, int>>.value(const <String, int>{});
  }

  void emitVisitedRegionIds(Set<String> visitedRegionIds) {
    _visitedRegionIds = visitedRegionIds;
    _visitedPolygonRecords = _recordsFromIds(visitedRegionIds);
    _visitedRegionIdsController.add(visitedRegionIds);
    _visitedPolygonRecordsController.add(_visitedPolygonRecords);
  }

  Future<void> dispose() async {
    await _visitedRegionIdsController.close();
    await _visitedPolygonRecordsController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  static List<VisitedPolygonRecord> _recordsFromIds(Set<String> ids) {
    final sortedIds = ids.toList()..sort();
    return List<VisitedPolygonRecord>.generate(sortedIds.length, (index) {
      return VisitedPolygonRecord(
        profileId: 'user-1',
        polygonId: sortedIds[index],
        visitedAt: DateTime(2026, 5, 1).add(Duration(days: index)),
      );
    });
  }
}

class _FakeYouCommentService implements CommentService {
  final List<ActivityComment> _comments = <ActivityComment>[];
  final StreamController<List<ActivityComment>> _controller =
      StreamController<List<ActivityComment>>.broadcast();

  @override
  Stream<List<ActivityComment>> watchComments(String activityId) {
    return Stream<List<ActivityComment>>.multi((controller) {
      controller.add(List<ActivityComment>.from(_comments));
      final subscription = _controller.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Stream<int> watchCommentCount(String activityId) {
    return Stream<int>.multi((controller) {
      controller.add(_comments.length);
      final subscription = _controller.stream.listen(
        (list) => controller.add(list.length),
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<ActivityComment> addComment({
    required String activityId,
    required String authorId,
    required String authorDisplayName,
    required String text,
    String? authorUsername,
    String? authorPhotoUrl,
  }) async {
    final comment = ActivityComment(
      id: 'c${_comments.length + 1}',
      activityId: activityId,
      authorId: authorId,
      authorDisplayName: authorDisplayName,
      text: text.trim(),
      createdAt: DateTime(2026, 8, 6),
    );
    _comments.insert(0, comment);
    _controller.add(List<ActivityComment>.from(_comments));
    return comment;
  }

  Future<void> dispose() => _controller.close();
}

class _FakeUser implements firebase_auth.User {
  _FakeUser({required this.uid, required this.email});

  @override
  final String uid;

  @override
  final String? email;

  @override
  bool get emailVerified => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
