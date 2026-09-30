import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/you/models/stats_metric_bucket.dart';
import 'package:roam_io/features/you/services/stats_aggregation_service.dart';

void main() {
  const service = StatsAggregationService();

  group('Statistics range aggregation', () {
    test('every fixed range has the expected chronological week count', () {
      final now = DateTime.now();
      final dates = <DateTime>[
        now.subtract(const Duration(days: 2)),
        now.subtract(const Duration(days: 40)),
      ];
      const expected = <StatsTimeRange, int>{
        StatsTimeRange.fourWeeks: 4,
        StatsTimeRange.threeMonths: 13,
        StatsTimeRange.sixMonths: 26,
        StatsTimeRange.oneYear: 52,
      };

      for (final entry in expected.entries) {
        final buckets = service.weeklyBucketsFromDatesForRange(
          dates,
          entry.key,
        );

        expect(buckets, hasLength(entry.value));
        for (var index = 1; index < buckets.length; index++) {
          expect(
            buckets[index].weekStart.difference(buckets[index - 1].weekStart),
            const Duration(days: 7),
          );
        }
      }
    });

    test('quiet weeks remain visible after older activity', () {
      final currentWeek = startOfWeek(DateTime.now());
      final oldActivity = currentWeek.subtract(const Duration(days: 8 * 7));

      final buckets = service.weeklyBucketsFromDatesForRange(<DateTime>[
        oldActivity,
      ], StatsTimeRange.threeMonths);

      expect(buckets.last.weekStart, currentWeek);
      expect(buckets.last.value, 0);
      expect(buckets.any((bucket) => bucket.value == 1), isTrue);
      expect(
        buckets.skipWhile((bucket) => bucket.value == 0).skip(1),
        everyElement(
          predicate<StatsMetricBucket>((bucket) => bucket.value == 0),
        ),
      );
    });

    test('sparse activity preserves gaps and later resumptions', () {
      final currentWeek = startOfWeek(DateTime.now());
      final dates = <DateTime>[
        currentWeek.subtract(const Duration(days: 5 * 7)),
        currentWeek.subtract(const Duration(days: 2 * 7)),
        currentWeek,
      ];

      final buckets = service.weeklyBucketsFromDatesForRange(
        dates,
        StatsTimeRange.threeMonths,
      );
      final tail = buckets.sublist(buckets.length - 6);

      expect(tail.map((bucket) => bucket.value), <int>[1, 0, 0, 1, 0, 1]);
    });

    test('All spans from earliest activity through the current week', () {
      final currentWeek = startOfWeek(DateTime.now());
      final earliest = currentWeek.subtract(const Duration(days: 80 * 7));

      final buckets = service.weeklyBucketsFromDatesForRange(<DateTime>[
        earliest,
        currentWeek,
      ], StatsTimeRange.all);

      expect(buckets, hasLength(81));
      expect(buckets.first.weekStart, earliest);
      expect(buckets.last.weekStart, currentWeek);
      expect(buckets.first.value, 1);
      expect(buckets.last.value, 1);
    });
  });
}
