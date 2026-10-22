import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/you/models/stats_metric_bucket.dart';
import 'package:roam_io/features/you/widgets/stats_weekly_chart.dart';

void main() {
  List<StatsMetricBucket> buckets(List<int> values) {
    final start = DateTime(2026, 1, 5);
    return <StatsMetricBucket>[
      for (var index = 0; index < values.length; index++)
        StatsMetricBucket(
          label: formatWeekAxisLabel(start.add(Duration(days: index * 7))),
          value: values[index],
          weekStart: start.add(Duration(days: index * 7)),
        ),
    ];
  }

  Future<void> pumpChart(
    WidgetTester tester, {
    required List<StatsMetricBucket> values,
    bool hasData = true,
    List<StatsMetricBucket> Function(StatsTimeRange)? bucketsForRange,
    Size size = const Size(390, 260),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: StatsWeeklyChart(
              buckets: values,
              bucketsForRange: bucketsForRange,
              hasData: hasData,
              emptyMessage: 'No activity yet',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows a deliberate empty state only when there is no data', (
    tester,
  ) async {
    await pumpChart(
      tester,
      values: buckets(const <int>[0, 0, 0, 0]),
      hasData: false,
    );

    expect(find.text('No activity yet'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('stats-graph-point-0')),
      findsNothing,
    );
  });

  testWidgets('renders valid all-zero and one-point series cleanly', (
    tester,
  ) async {
    await pumpChart(tester, values: buckets(const <int>[0, 0, 0, 0]));
    expect(find.text('No activity yet'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('stats-graph-point-3')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await pumpChart(tester, values: buckets(const <int>[1234]));
    await tester.tap(find.byKey(const ValueKey<String>('stats-graph-point-0')));
    await tester.pump();

    expect(find.textContaining('1,234'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches ranges and replaces the point set consistently', (
    tester,
  ) async {
    await pumpChart(
      tester,
      values: buckets(List<int>.filled(13, 1)),
      bucketsForRange: (range) => buckets(
        List<int>.filled(range == StatsTimeRange.fourWeeks ? 4 : 13, 1),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('stats-graph-point-12')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey<String>('stats-range-4W')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('stats-graph-point-3')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('stats-graph-point-12')),
      findsNothing,
    );
  });

  testWidgets('restores a separate selected range for each Statistics tab', (
    tester,
  ) async {
    var activeChart = 'locations';
    late StateSetter updateHost;
    List<StatsMetricBucket> valuesFor(StatsTimeRange range) {
      final count = range.weekCount ?? 80;
      return buckets(List<int>.filled(count, 1));
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return Padding(
                padding: const EdgeInsets.all(24),
                child: StatsWeeklyChart(
                  key: ValueKey<String>(activeChart),
                  buckets: valuesFor(StatsTimeRange.threeMonths),
                  bucketsForRange: valuesFor,
                  rangeStorageId: 'stats-$activeChart-range',
                  emptyMessage: 'No activity yet',
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('stats-range-4W')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('stats-graph-point-3')),
      findsOneWidget,
    );

    updateHost(() => activeChart = 'tiles');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('stats-range-1Y')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('stats-graph-point-51')),
      findsOneWidget,
    );

    updateHost(() => activeChart = 'locations');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('stats-graph-point-3')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('stats-graph-point-12')),
      findsNothing,
    );

    updateHost(() => activeChart = 'tiles');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('stats-graph-point-51')),
      findsOneWidget,
    );
  });

  testWidgets('handles many weeks, outliers, and a narrow screen', (
    tester,
  ) async {
    final values = <int>[
      for (var index = 0; index < 120; index++)
        if (index == 64) 2500000000 else if (index % 11 == 0) 8 else 0,
    ];
    await pumpChart(
      tester,
      values: buckets(values),
      size: const Size(320, 260),
    );

    expect(
      find.byKey(const ValueKey<String>('stats-graph-point-119')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
