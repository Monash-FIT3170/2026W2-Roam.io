import 'dart:math' as math;

/// A stable, human-readable vertical scale for Statistics charts.
///
/// Domains always begin at zero because every Statistics series represents a
/// count or accumulated value. The upper bound is rounded to a 1/2/2.5/5/10
/// step so small series remain legible and large outliers do not produce noisy
/// or duplicated labels.
class StatsChartScale {
  const StatsChartScale._({required this.maxY, required this.ticks});

  factory StatsChartScale.fromValues(Iterable<int> values) {
    final maximum = values.fold<int>(0, math.max);
    if (maximum <= 1) {
      return const StatsChartScale._(maxY: 1, ticks: <double>[0, 1]);
    }

    const targetIntervals = 3;
    final interval = _niceCeiling(maximum / targetIntervals);
    final maxY = (maximum / interval).ceil() * interval;
    final ticks = <double>[
      for (var value = 0.0; value <= maxY + interval / 2; value += interval)
        value,
    ];

    return StatsChartScale._(maxY: maxY, ticks: ticks);
  }

  final double maxY;
  final List<double> ticks;

  static double _niceCeiling(double value) {
    if (value <= 0) return 1;
    final exponent = math.pow(10, (math.log(value) / math.ln10).floor());
    final fraction = value / exponent;
    final niceFraction = fraction <= 1
        ? 1.0
        : fraction <= 2
        ? 2.0
        : fraction <= 2.5
        ? 2.5
        : fraction <= 5
        ? 5.0
        : 10.0;
    return niceFraction * exponent;
  }
}

/// Compact axis formatting that remains distinct from the exact tooltip value.
String formatStatsAxisValue(double value) {
  if (value == 0) return '0';
  if (value.abs() >= 1000000000) return _compact(value / 1000000000, 'B');
  if (value.abs() >= 1000000) return _compact(value / 1000000, 'M');
  if (value.abs() >= 1000) return _compact(value / 1000, 'K');
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}

String _compact(double value, String suffix) {
  final decimals = value.abs() >= 10 || value == value.roundToDouble() ? 0 : 1;
  return '${value.toStringAsFixed(decimals)}$suffix';
}
