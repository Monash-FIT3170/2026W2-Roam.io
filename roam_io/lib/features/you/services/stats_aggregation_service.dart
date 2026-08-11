import 'dart:math' as math;

import '../../journeys/domain/journey.dart';
import '../../map/data/place_of_interest.dart';
import '../../map/domain/visit_event.dart';
import '../../map/data/visit.dart';
import '../../profile/domain/home_base.dart';
import '../../profile/domain/stats_summary.dart';
import '../../profile/domain/visited_polygon_meta.dart';
import '../../profile/domain/visited_polygon_record.dart';
import '../../profile/domain/xp_event.dart';
import '../models/stats_breakdown_item.dart';
import '../models/stats_metric_bucket.dart';

/// Approximate Melbourne metropolitan land area for v1 coverage percentage.
const double melbourneMetroAreaSquareMetres = 9_900_000_000;

/// Pure aggregation helpers for Stats tab charts and hero numbers.
class StatsAggregationService {
  const StatsAggregationService();

  int xpThisWeek(List<XpEvent> events) {
    final now = DateTime.now();
    final weekStart = startOfWeek(now);
    final weekEnd = weekStart.add(const Duration(days: 7));
    return events
        .where(
          (event) =>
              !event.earnedAt.isBefore(weekStart) &&
              event.earnedAt.isBefore(weekEnd),
        )
        .fold<int>(0, (sum, event) => sum + event.amount);
  }

  int xpLastWeek(List<XpEvent> events) {
    final weekStart = startOfWeek(
      DateTime.now(),
    ).subtract(const Duration(days: 7));
    final weekEnd = weekStart.add(const Duration(days: 7));
    return events
        .where(
          (event) =>
              !event.earnedAt.isBefore(weekStart) &&
              event.earnedAt.isBefore(weekEnd),
        )
        .fold<int>(0, (sum, event) => sum + event.amount);
  }

  Map<XpEventSource, int> xpBySource(List<XpEvent> events) {
    final totals = <XpEventSource, int>{};
    for (final event in events) {
      totals.update(
        event.source,
        (value) => value + event.amount,
        ifAbsent: () => event.amount,
      );
    }
    return totals;
  }

  List<StatsMetricBucket> weeklyBucketsFromDates(List<DateTime> dates) {
    final anchor = dates.isEmpty
        ? startOfWeek(DateTime.now())
        : startOfWeek(
            dates.reduce(
              (latest, value) => value.isAfter(latest) ? value : latest,
            ),
          );
    final starts = List<DateTime>.generate(
      6,
      (index) => anchor.subtract(Duration(days: 7 * (5 - index))),
    );

    return starts.map((start) {
      final end = start.add(const Duration(days: 7));
      final count = dates
          .where((date) => !date.isBefore(start) && date.isBefore(end))
          .length;
      return StatsMetricBucket(
        label: formatWeekAxisLabel(start),
        value: count,
        weekStart: start,
      );
    }).toList();
  }

  List<StatsMetricBucket> weeklyBucketsFromXpEvents(List<XpEvent> events) {
    final dates = events.map((event) => event.earnedAt).toList();
    final anchor = dates.isEmpty
        ? startOfWeek(DateTime.now())
        : startOfWeek(
            dates.reduce(
              (latest, value) => value.isAfter(latest) ? value : latest,
            ),
          );
    final starts = List<DateTime>.generate(
      6,
      (index) => anchor.subtract(Duration(days: 7 * (5 - index))),
    );

    return starts.map((start) {
      final end = start.add(const Duration(days: 7));
      final total = events
          .where(
            (event) =>
                !event.earnedAt.isBefore(start) &&
                event.earnedAt.isBefore(end),
          )
          .fold<int>(0, (sum, event) => sum + event.amount);
      return StatsMetricBucket(
        label: formatWeekAxisLabel(start),
        value: total,
        weekStart: start,
      );
    }).toList();
  }

  List<StatsMetricBucket> emptyRecentBuckets() {
    final anchor = startOfWeek(DateTime.now());
    return List<DateTime>.generate(
      6,
      (index) => anchor.subtract(Duration(days: 7 * (5 - index))),
    ).map((start) {
      return StatsMetricBucket(
        label: formatWeekAxisLabel(start),
        value: 0,
        weekStart: start,
      );
    }).toList();
  }

  List<StatsMetricBucket> visitEventBuckets(List<VisitEvent> events) {
    return weeklyBucketsFromDates(
      events.map((event) => event.visitedAt).toList(),
    );
  }

  List<StatsMetricBucket> visitSummaryBuckets(List<Visit> visits) {
    return weeklyBucketsFromDates(
      visits.map((visit) => visit.lastVisitedAt ?? visit.visitedAt).toList(),
    );
  }

  List<StatsMetricBucket> tileUnlockBuckets(
    List<VisitedPolygonRecord> tileRecords,
  ) {
    return weeklyBucketsFromDates(
      tileRecords.map((record) => record.visitedAt).toList(),
    );
  }

  List<StatsMetricBucket> journeyBuckets(List<Journey> journeys) {
    return weeklyBucketsFromDates(
      journeys.map((journey) => journey.startTime).toList(),
    );
  }

  int totalVisitEvents(List<Visit> visits) {
    return visits.fold<int>(
      0,
      (sum, visit) => sum + (visit.visitCount <= 0 ? 1 : visit.visitCount),
    );
  }

  int uniquePlaces(List<Visit> visits) => visits.length;

  double totalJourneyDistance(List<Journey> journeys) {
    return journeys.fold<double>(
      0,
      (sum, journey) => sum + journey.distanceMeters,
    );
  }

  int totalJourneySeconds(List<Journey> journeys) {
    return journeys.fold<int>(
      0,
      (sum, journey) => sum + journey.durationSeconds,
    );
  }

  int tileCountFromSummary(
    StatsSummary? summary,
    List<VisitedPolygonRecord> tiles,
  ) {
    if (summary != null && summary.totalTiles > 0) {
      return summary.totalTiles;
    }
    return tiles.length;
  }

  BestXpDay? bestXpDay(List<XpEvent> events) {
    if (events.isEmpty) return null;

    final totalsByDay = <DateTime, int>{};
    for (final event in events) {
      final day = _dateOnly(event.earnedAt);
      totalsByDay.update(day, (value) => value + event.amount, ifAbsent: () => event.amount);
    }

    final best = totalsByDay.entries.reduce(
      (left, right) => left.value >= right.value ? left : right,
    );
    return BestXpDay(day: best.key, amount: best.value);
  }

  String xpInsightMessage({
    required List<XpEvent> events,
    required int streakDays,
    required int xpThisWeek,
    required int xpLastWeek,
  }) {
    final best = bestXpDay(events);
    if (best != null && best.amount > 0) {
      return 'Best day: +${best.amount} XP on ${_weekdayLabel(best.day)}';
    }
    if (streakDays >= 2) {
      return '$streakDays-day XP streak — keep exploring!';
    }
    if (xpThisWeek > xpLastWeek && xpThisWeek > 0) {
      return '+${xpThisWeek - xpLastWeek} XP vs last week';
    }
    if (events.isEmpty) {
      return 'Visit places or unlock tiles to start earning XP';
    }
    return 'Every unlock and visit adds to your explorer score';
  }

  List<StatsBreakdownItem> xpSourceBreakdown({
    required Map<XpEventSource, int> eventTotals,
    required StatsSummary summary,
  }) {
    final visitXp = eventTotals[XpEventSource.visit] ?? 0;
    final tileXp = eventTotals[XpEventSource.tileUnlock] ?? 0;
    final journeyXp = eventTotals[XpEventSource.journey] ?? 0;

    return <StatsBreakdownItem>[
      StatsBreakdownItem(
        label: 'Visits',
        value: visitXp > 0 ? visitXp : summary.xpFromVisits,
      ),
      StatsBreakdownItem(
        label: 'Tiles',
        value: tileXp > 0 ? tileXp : summary.xpFromTileUnlocks,
      ),
      StatsBreakdownItem(
        label: 'Journeys',
        value: journeyXp > 0 ? journeyXp : summary.xpFromJourneys,
      ),
    ]..sort((left, right) => right.value.compareTo(left.value));
  }

  String xpSourceLabel(XpEventSource source) {
    switch (source) {
      case XpEventSource.visit:
        return 'Visit';
      case XpEventSource.tileUnlock:
        return 'Tile unlock';
      case XpEventSource.journey:
        return 'Journey';
      case XpEventSource.unknown:
        return 'Other';
    }
  }

  List<TopPlaceEntry> topPlaces({
    required List<VisitEvent> events,
    required List<Visit> visits,
    int limit = 3,
  }) {
    if (events.isNotEmpty) {
      final counts = <int, ({String name, int count})>{};
      for (final event in events) {
        final existing = counts[event.placeId];
        counts[event.placeId] = (
          name: event.placeName,
          count: (existing?.count ?? 0) + 1,
        );
      }
      final ranked = counts.values.toList()
        ..sort((left, right) => right.count.compareTo(left.count));
      return ranked
          .take(limit)
          .map(
            (entry) => TopPlaceEntry(
              placeName: entry.name,
              visitCount: entry.count,
            ),
          )
          .toList();
    }

    final rankedVisits = visits.toList()
      ..sort((left, right) => right.visitCount.compareTo(left.visitCount));
    return rankedVisits
        .take(limit)
        .map(
          (visit) => TopPlaceEntry(
            placeName: visit.placeName,
            visitCount: visit.visitCount,
          ),
        )
        .toList();
  }

  List<StatsBreakdownItem> categoryBreakdown({
    required List<VisitEvent> events,
    required List<Visit> visits,
  }) {
    final counts = <String, int>{};

    if (events.isNotEmpty) {
      for (final event in events) {
        final label = PlaceCategory.fromString(event.category).displayName;
        counts.update(label, (value) => value + 1, ifAbsent: () => 1);
      }
    } else {
      for (final visit in visits) {
        final count = visit.visitCount <= 0 ? 1 : visit.visitCount;
        final label = PlaceCategory.fromString(visit.category).displayName;
        counts.update(label, (value) => value + count, ifAbsent: () => count);
      }
    }

    return counts.entries
        .map(
          (entry) => StatsBreakdownItem(label: entry.key, value: entry.value),
        )
        .toList()
      ..sort((left, right) => right.value.compareTo(left.value));
  }

  String? explorerTimeLabel(List<VisitEvent> events) {
    if (events.isEmpty) return null;

    var morning = 0;
    var afternoon = 0;
    var evening = 0;
    var night = 0;

    for (final event in events) {
      final hour = event.visitedAt.hour;
      if (hour >= 5 && hour < 12) {
        morning += 1;
      } else if (hour >= 12 && hour < 17) {
        afternoon += 1;
      } else if (hour >= 17 && hour < 22) {
        evening += 1;
      } else {
        night += 1;
      }
    }

    final buckets = <String, int>{
      'Morning explorer': morning,
      'Afternoon explorer': afternoon,
      'Evening explorer': evening,
      'Night explorer': night,
    };
    return buckets.entries.reduce(
      (left, right) => left.value >= right.value ? left : right,
    ).key;
  }

  double? furthestFromHomeKm({
    required List<VisitEvent> events,
    required HomeBase? homeBase,
  }) {
    if (homeBase == null || events.isEmpty) return null;

    var furthest = 0.0;
    for (final event in events) {
      final distance = _haversineKm(
        homeBase.lat,
        homeBase.lng,
        event.lat,
        event.lng,
      );
      if (distance > furthest) {
        furthest = distance;
      }
    }
    return furthest;
  }

  List<StatsBreakdownItem> transportModeBreakdown(List<Journey> journeys) {
    final counts = <String, int>{};
    for (final journey in journeys) {
      final label = journey.transportMode.displayName;
      counts.update(label, (value) => value + 1, ifAbsent: () => 1);
    }

    return counts.entries
        .map(
          (entry) => StatsBreakdownItem(label: entry.key, value: entry.value),
        )
        .toList()
      ..sort((left, right) => right.value.compareTo(left.value));
  }

  Journey? longestJourney(List<Journey> journeys) {
    if (journeys.isEmpty) return null;
    return journeys.reduce(
      (left, right) =>
          left.distanceMeters >= right.distanceMeters ? left : right,
    );
  }

  Journey? mostTilesJourney(List<Journey> journeys) {
    if (journeys.isEmpty) return null;
    return journeys.reduce(
      (left, right) => left.tilesUnlocked >= right.tilesUnlocked ? left : right,
    );
  }

  Journey? bestYieldJourney(List<Journey> journeys) {
    Journey? best;
    var bestYield = 0.0;

    for (final journey in journeys) {
      final yield = journey.tilesPerKm ??
          (journey.distanceMeters <= 0
              ? 0
              : journey.tilesUnlocked / (journey.distanceMeters / 1000));
      if (yield > bestYield) {
        bestYield = yield;
        best = journey;
      }
    }

    return best;
  }

  String journeyInsightMessage(List<Journey> journeys) {
    final bestYield = bestYieldJourney(journeys);
    if (bestYield != null && (bestYield.tilesPerKm ?? 0) > 0) {
      final yield = bestYield.tilesPerKm ??
          bestYield.tilesUnlocked / (bestYield.distanceMeters / 1000);
      return 'Best exploration yield: ${yield.toStringAsFixed(1)} tiles/km';
    }

    final longest = longestJourney(journeys);
    if (longest != null) {
      return 'Longest journey: ${(longest.distanceMeters / 1000).toStringAsFixed(1)} km';
    }

    return 'Start a journey to unlock tiles along your route';
  }

  int unlockStreakDays(List<VisitedPolygonRecord> records) {
    if (records.isEmpty) return 0;

    final unlockDays = records.map((record) => _dateOnly(record.visitedAt)).toSet();
    var cursor = _dateOnly(DateTime.now());
    if (!unlockDays.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var streak = 0;
    while (unlockDays.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  VisitedPolygonMeta? biggestUnlock(
    Map<String, VisitedPolygonMeta> metaByPolygonId,
  ) {
    VisitedPolygonMeta? biggest;
    var largestArea = 0.0;

    for (final meta in metaByPolygonId.values) {
      final area = meta.areaSquareMetres ?? 0;
      if (area > largestArea) {
        largestArea = area;
        biggest = meta;
      }
    }

    return biggest;
  }

  double melbourneCoveragePercent(double unlockedAreaSquareMetres) {
    if (unlockedAreaSquareMetres <= 0) return 0;
    return (unlockedAreaSquareMetres / melbourneMetroAreaSquareMetres * 100)
        .clamp(0, 100);
  }

  List<TopTileEntry> topTilesByEntryCount({
    required Map<String, int> entryCounts,
    required Map<String, VisitedPolygonMeta> metaByPolygonId,
    int limit = 5,
  }) {
    final ranked = entryCounts.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));

    return ranked
        .take(limit)
        .map((entry) {
          final meta = metaByPolygonId[entry.key];
          return TopTileEntry(
            polygonId: entry.key,
            displayName: meta?.name ?? 'Tile ${entry.key.substring(0, 6)}',
            entryCount: entry.value,
          );
        })
        .toList();
  }

  String tilesInsightMessage({
    required Map<String, VisitedPolygonMeta> metaByPolygonId,
    required Map<String, int> entryCounts,
    required int unlockStreak,
  }) {
    final biggest = biggestUnlock(metaByPolygonId);
    if (biggest != null && (biggest.areaSquareMetres ?? 0) > 0) {
      final hectares = (biggest.areaSquareMetres! / 10_000).toStringAsFixed(1);
      final name = biggest.name ?? 'Unnamed tile';
      return 'Biggest unlock: $name · $hectares ha';
    }

    final loyal = topTilesByEntryCount(
      entryCounts: entryCounts,
      metaByPolygonId: metaByPolygonId,
      limit: 1,
    );
    if (loyal.isNotEmpty && loyal.first.entryCount >= 3) {
      return '${loyal.first.displayName} entered ${loyal.first.entryCount} times';
    }

    if (unlockStreak >= 2) {
      return '$unlockStreak-day unlock streak';
    }

    return 'Unlock new SA1 tiles as you roam the map';
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _weekdayLabel(DateTime day) {
    const labels = <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    return labels[day.weekday - DateTime.monday];
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;
}
