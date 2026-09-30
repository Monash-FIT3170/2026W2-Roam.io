import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/you/models/stats_chart_scale.dart';

void main() {
  group('StatsChartScale', () {
    test('uses a deliberate non-zero domain for empty and zero series', () {
      for (final values in <List<int>>[
        const <int>[],
        const <int>[0],
        const <int>[0, 0, 0, 0],
      ]) {
        final scale = StatsChartScale.fromValues(values);

        expect(scale.maxY, 1);
        expect(scale.ticks, const <double>[0, 1]);
      }
    });

    test('keeps identical and single values inside a readable nice domain', () {
      final single = StatsChartScale.fromValues(const <int>[7]);
      final identical = StatsChartScale.fromValues(const <int>[25, 25, 25]);

      expect(single.maxY, greaterThanOrEqualTo(7));
      expect(identical.maxY, greaterThanOrEqualTo(25));
      expect(single.ticks.toSet().length, single.ticks.length);
      expect(identical.ticks.toSet().length, identical.ticks.length);
    });

    test(
      'handles small series, large values, and outliers without clipping',
      () {
        final small = StatsChartScale.fromValues(const <int>[0, 1, 2, 3]);
        final large = StatsChartScale.fromValues(const <int>[
          2,
          4,
          8,
          2500000000,
        ]);

        expect(small.maxY, greaterThanOrEqualTo(3));
        expect(large.maxY, greaterThanOrEqualTo(2500000000));
        expect(large.ticks.toSet().length, large.ticks.length);
        expect(formatStatsAxisValue(2500000000), '2.5B');
        expect(formatStatsAxisValue(12500), '13K');
      },
    );
  });
}
