import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/journeys/domain/journey.dart';
import 'package:roam_io/features/journeys/domain/journey_location.dart';
import 'package:roam_io/features/journeys/domain/transport_mode.dart';
import 'package:roam_io/features/map/data/visit.dart';
import 'package:roam_io/features/map/domain/visit_event.dart';
import 'package:roam_io/features/profile/domain/home_base.dart';
import 'package:roam_io/features/profile/domain/stats_summary.dart';
import 'package:roam_io/features/profile/domain/visited_polygon_meta.dart';
import 'package:roam_io/features/profile/domain/visited_polygon_record.dart';
import 'package:roam_io/features/profile/domain/xp_event.dart';
import 'package:roam_io/features/you/models/stats_metric_bucket.dart';
import 'package:roam_io/features/you/services/stats_aggregation_service.dart';

VisitEvent _event({
  required String id,
  required int placeId,
  required String category,
  required DateTime visitedAt,
  String placeName = 'Place',
  double lat = -37.8,
  double lng = 144.9,
}) {
  return VisitEvent(
    id: id,
    placeId: placeId,
    googlePlaceId: 'g$placeId',
    placeName: placeName,
    regionId: 'r$placeId',
    category: category,
    lat: lat,
    lng: lng,
    visitedAt: visitedAt,
  );
}

Visit _visit({
  required int placeId,
  required DateTime visitedAt,
  int visitCount = 1,
  DateTime? lastVisitedAt,
  String category = 'food_drink',
}) {
  return Visit(
    placeId: placeId,
    googlePlaceId: 'g$placeId',
    placeName: 'Place $placeId',
    regionId: 'r$placeId',
    category: category,
    visitedAt: visitedAt,
    visitCount: visitCount,
    lastVisitedAt: lastVisitedAt,
  );
}

Journey _journey({
  required String id,
  required DateTime start,
  required double distanceMeters,
  required int durationSeconds,
  TransportMode mode = TransportMode.walk,
  int tilesUnlocked = 0,
  double? tilesPerKm,
}) {
  return Journey(
    id: id,
    userId: 'u1',
    startTime: start,
    endTime: start.add(Duration(seconds: durationSeconds)),
    startLocation: JourneyLocation(
      latLng: const LatLng(-37.8, 144.9),
      displayName: 'Start',
    ),
    endLocation: JourneyLocation(
      latLng: const LatLng(-37.81, 144.91),
      displayName: 'End',
    ),
    transportMode: mode,
    encodedRoute: 'abc',
    distanceMeters: distanceMeters,
    durationSeconds: durationSeconds,
    tilesUnlocked: tilesUnlocked,
    tilesPerKm: tilesPerKm,
  );
}

XpEvent _xp({
  required String id,
  required int amount,
  required DateTime earnedAt,
  XpEventSource source = XpEventSource.visit,
}) {
  return XpEvent(
    id: id,
    amount: amount,
    earnedAt: earnedAt,
    source: source,
  );
}

void main() {
  const service = StatsAggregationService();

  group('StatsAggregationService visit metrics', () {
    test('totalVisitEvents sums visitCount and treats non-positive as 1', () {
      final visits = [
        _visit(placeId: 1, visitedAt: DateTime(2026, 5, 1), visitCount: 3),
        _visit(placeId: 2, visitedAt: DateTime(2026, 5, 2), visitCount: 0),
        _visit(placeId: 3, visitedAt: DateTime(2026, 5, 3), visitCount: -2),
        _visit(placeId: 4, visitedAt: DateTime(2026, 5, 4)),
      ];

      expect(service.totalVisitEvents(visits), 3 + 1 + 1 + 1);
      expect(service.uniquePlaces(visits), 4);
      expect(service.totalVisitEvents(const []), 0);
    });

    test('categoryBreakdown prefers events and falls back to visit counts', () {
      final events = [
        _event(
          id: 'e1',
          placeId: 1,
          category: 'food_drink',
          visitedAt: DateTime(2026, 5, 1),
        ),
        _event(
          id: 'e2',
          placeId: 2,
          category: 'food_drink',
          visitedAt: DateTime(2026, 5, 2),
        ),
        _event(
          id: 'e3',
          placeId: 3,
          category: 'nature',
          visitedAt: DateTime(2026, 5, 3),
        ),
      ];

      final fromEvents = service.categoryBreakdown(
        events: events,
        visits: const [],
      );
      expect(fromEvents.first.label, 'Food & Drink');
      expect(fromEvents.first.value, 2);
      expect(fromEvents.last.label, 'Nature');
      expect(fromEvents.last.value, 1);

      final fromVisits = service.categoryBreakdown(
        events: const [],
        visits: [
          _visit(
            placeId: 1,
            visitedAt: DateTime(2026, 5, 1),
            visitCount: 4,
            category: 'nature',
          ),
          _visit(
            placeId: 2,
            visitedAt: DateTime(2026, 5, 2),
            visitCount: 0,
            category: 'food_drink',
          ),
        ],
      );
      expect(fromVisits.first.label, 'Nature');
      expect(fromVisits.first.value, 4);
      expect(fromVisits.last.value, 1);
    });

    test('visitStreakDays ignores gaps and accepts yesterday-ending streaks', () {
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);

      expect(
        service.visitStreakDays(
          events: [
            _event(
              id: 'a',
              placeId: 1,
              category: 'nature',
              visitedAt: day.subtract(const Duration(days: 1)),
            ),
            _event(
              id: 'b',
              placeId: 2,
              category: 'nature',
              visitedAt: day.subtract(const Duration(days: 2)),
            ),
          ],
          visits: const [],
        ),
        2,
      );

      expect(
        service.visitStreakDays(
          events: const [],
          visits: [
            _visit(placeId: 1, visitedAt: day, visitCount: 2),
            _visit(
              placeId: 2,
              visitedAt: day.subtract(const Duration(days: 1)),
              lastVisitedAt: day.subtract(const Duration(days: 1)),
            ),
          ],
        ),
        2,
      );
    });

    test('furthestFromHomeKm returns max haversine distance', () {
      final home = HomeBase(
        lat: -37.8136,
        lng: 144.9631,
        setAt: DateTime(2026, 1, 1),
        label: 'Home',
      );
      final events = [
        _event(
          id: 'near',
          placeId: 1,
          category: 'other',
          visitedAt: DateTime(2026, 5, 1),
          lat: -37.82,
          lng: 144.97,
        ),
        _event(
          id: 'far',
          placeId: 2,
          category: 'other',
          visitedAt: DateTime(2026, 5, 2),
          lat: -38.15,
          lng: 145.15,
        ),
      ];

      final km = service.furthestFromHomeKm(events: events, homeBase: home);
      expect(km, isNotNull);
      expect(km!, greaterThan(30));
      expect(km, lessThan(60));
    });
  });

  group('StatsAggregationService XP metrics', () {
    test('xpThisWeek and xpLastWeek use Monday-aligned half-open weeks', () {
      final weekStart = startOfWeek(DateTime.now());
      final events = [
        _xp(id: 'this', amount: 40, earnedAt: weekStart.add(const Duration(hours: 2))),
        _xp(
          id: 'this-end',
          amount: 10,
          earnedAt: weekStart.add(const Duration(days: 6, hours: 23)),
        ),
        _xp(
          id: 'last',
          amount: 70,
          earnedAt: weekStart.subtract(const Duration(days: 2)),
        ),
        _xp(
          id: 'older',
          amount: 999,
          earnedAt: weekStart.subtract(const Duration(days: 10)),
        ),
        _xp(
          id: 'next-week-boundary',
          amount: 5,
          earnedAt: weekStart.add(const Duration(days: 7)),
        ),
      ];

      expect(service.xpThisWeek(events), 50);
      expect(service.xpLastWeek(events), 70);
    });

    test('xpBySource and xpSourceBreakdown include milestones', () {
      final events = [
        _xp(id: 'v', amount: 30, earnedAt: DateTime(2026, 5, 1)),
        _xp(
          id: 'm',
          amount: 100,
          earnedAt: DateTime(2026, 5, 2),
          source: XpEventSource.milestone,
        ),
        _xp(
          id: 't',
          amount: 20,
          earnedAt: DateTime(2026, 5, 3),
          source: XpEventSource.tileUnlock,
        ),
      ];

      final bySource = service.xpBySource(events);
      expect(bySource[XpEventSource.visit], 30);
      expect(bySource[XpEventSource.milestone], 100);
      expect(bySource[XpEventSource.tileUnlock], 20);

      final breakdown = service.xpSourceBreakdown(
        eventTotals: bySource,
        summary: const StatsSummary(),
      );
      expect(breakdown.map((item) => item.label).toList(), contains('Milestones'));
      expect(
        breakdown.firstWhere((item) => item.label == 'Milestones').value,
        100,
      );
      expect(service.xpSourceLabel(XpEventSource.milestone), 'Milestone');
    });

    test('bestXpDay picks the calendar day with the highest XP', () {
      final events = [
        _xp(id: 'a', amount: 20, earnedAt: DateTime(2026, 5, 1, 8)),
        _xp(id: 'b', amount: 30, earnedAt: DateTime(2026, 5, 1, 20)),
        _xp(id: 'c', amount: 40, earnedAt: DateTime(2026, 5, 2, 12)),
      ];

      final best = service.bestXpDay(events);
      expect(best, isNotNull);
      expect(best!.amount, 50);
      expect(best.day.day, 1);
      expect(service.bestXpDay(const []), isNull);
    });

    test('weeklyBucketsFromXpEvents sums amounts into six week windows', () {
      final anchor = startOfWeek(DateTime(2026, 5, 13)); // Wednesday → Mon 11 May
      final events = [
        _xp(id: 'a', amount: 10, earnedAt: anchor),
        _xp(id: 'b', amount: 15, earnedAt: anchor.add(const Duration(days: 2))),
        _xp(
          id: 'c',
          amount: 7,
          earnedAt: anchor.subtract(const Duration(days: 7)),
        ),
      ];

      final buckets = service.weeklyBucketsFromXpEvents(events);
      expect(buckets, hasLength(6));
      expect(buckets.last.value, 25);
      expect(buckets[buckets.length - 2].value, 7);
    });
  });

  group('StatsAggregationService journey and tile metrics', () {
    test('journey totals and transport breakdown are accurate', () {
      final journeys = [
        _journey(
          id: 'j1',
          start: DateTime(2026, 5, 1, 9),
          distanceMeters: 2500,
          durationSeconds: 1800,
          mode: TransportMode.walk,
          tilesUnlocked: 4,
          tilesPerKm: 1.6,
        ),
        _journey(
          id: 'j2',
          start: DateTime(2026, 5, 2, 9),
          distanceMeters: 10000,
          durationSeconds: 3600,
          mode: TransportMode.drive,
          tilesUnlocked: 2,
          tilesPerKm: 0.2,
        ),
      ];

      expect(service.totalJourneyDistance(journeys), 12500);
      expect(service.totalJourneySeconds(journeys), 5400);
      expect(service.longestJourney(journeys)?.id, 'j2');
      expect(service.mostTilesJourney(journeys)?.id, 'j1');
      expect(service.bestYieldJourney(journeys)?.id, 'j1');

      final modes = service.transportModeBreakdown(journeys);
      expect(modes, hasLength(2));
      expect(modes.map((item) => item.value).toList(), everyElement(1));
    });

    test('tileCountFromSummary prefers summary then record length', () {
      final tiles = [
        VisitedPolygonRecord(
          profileId: 'u1',
          polygonId: 'p1',
          visitedAt: DateTime(2026, 5, 1),
        ),
        VisitedPolygonRecord(
          profileId: 'u1',
          polygonId: 'p2',
          visitedAt: DateTime(2026, 5, 2),
        ),
      ];

      expect(
        service.tileCountFromSummary(
          const StatsSummary(totalTiles: 9),
          tiles,
        ),
        9,
      );
      expect(service.tileCountFromSummary(const StatsSummary(), tiles), 2);
    });

    test('revealedAreaSquareMetres prefers summary then meta then estimate', () {
      final fromSummary = service.revealedAreaSquareMetres(
        summary: const StatsSummary(totalAreaSquareMetres: 1_500_000),
        polygonMeta: const {},
        tileCount: 99,
      );
      expect(fromSummary.squareMetres, 1_500_000);
      expect(fromSummary.isEstimated, isFalse);

      final fromMeta = service.revealedAreaSquareMetres(
        summary: const StatsSummary(),
        polygonMeta: {
          'a': VisitedPolygonMeta(
            polygonId: 'a',
            visitedAt: DateTime(2026, 5, 1),
            areaSquareMetres: 100_000,
          ),
          'b': VisitedPolygonMeta(
            polygonId: 'b',
            visitedAt: DateTime(2026, 5, 2),
            areaSquareMetres: 50_000,
          ),
        },
        tileCount: 2,
      );
      expect(fromMeta.squareMetres, 150_000);
      expect(fromMeta.isEstimated, isFalse);

      expect(
        service.melbourneCoveragePercent(melbourneMetroAreaSquareMetres),
        100,
      );
      expect(service.melbourneCoveragePercent(0), 0);
    });

    test('unlockStreakDays counts consecutive unlock days', () {
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      final records = [
        VisitedPolygonRecord(
          profileId: 'u1',
          polygonId: 'a',
          visitedAt: day,
        ),
        VisitedPolygonRecord(
          profileId: 'u1',
          polygonId: 'b',
          visitedAt: day.subtract(const Duration(days: 1)),
        ),
        VisitedPolygonRecord(
          profileId: 'u1',
          polygonId: 'c',
          visitedAt: day.subtract(const Duration(days: 4)),
        ),
      ];

      expect(service.unlockStreakDays(records), 2);
      expect(service.unlockStreakDays(const []), 0);
    });
  });

  group('StatsAggregationService chart buckets', () {
    test('emptyRecentBuckets returns six zero weeks ending this week', () {
      final buckets = service.emptyRecentBuckets();
      expect(buckets, hasLength(6));
      expect(buckets.every((bucket) => bucket.value == 0), isTrue);
      expect(buckets.last.weekStart, startOfWeek(DateTime.now()));
    });

    test('visitEventBuckets count events by week of visitedAt', () {
      final week = startOfWeek(DateTime(2026, 8, 12));
      final events = [
        _event(
          id: '1',
          placeId: 1,
          category: 'nature',
          visitedAt: week,
        ),
        _event(
          id: '2',
          placeId: 2,
          category: 'nature',
          visitedAt: week.add(const Duration(days: 1)),
        ),
        _event(
          id: '3',
          placeId: 3,
          category: 'nature',
          visitedAt: week.subtract(const Duration(days: 7)),
        ),
      ];

      final buckets = service.visitEventBuckets(events);
      expect(buckets.last.value, 2);
      expect(buckets[buckets.length - 2].value, 1);
    });
  });
}
