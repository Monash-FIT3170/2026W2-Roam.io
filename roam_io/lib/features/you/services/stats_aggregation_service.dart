import '../../journeys/domain/journey.dart';
import '../../map/domain/visit_event.dart';
import '../../map/data/visit.dart';
import '../../profile/domain/stats_summary.dart';
import '../../profile/domain/visited_polygon_record.dart';
import '../../profile/domain/xp_event.dart';
import '../models/stats_metric_bucket.dart';

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
}
