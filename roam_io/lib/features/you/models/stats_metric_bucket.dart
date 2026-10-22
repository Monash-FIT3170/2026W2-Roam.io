/// A single bucket in a weekly stats trend chart.
class StatsMetricBucket {
  const StatsMetricBucket({
    required this.label,
    required this.value,
    required this.weekStart,
  });

  final String label;
  final int value;
  final DateTime weekStart;

  String detailLabel(String metricLabel, {String unit = ''}) {
    final weekLabel = formatWeekDetailLabel(weekStart);
    final suffix = unit.isEmpty ? '' : ' $unit';
    return 'Week of $weekLabel · ${formatExactStatNumber(value)}$metricLabel$suffix';
  }
}

/// Time windows available on every Statistics trend chart.
enum StatsTimeRange { fourWeeks, threeMonths, sixMonths, oneYear, all }

extension StatsTimeRangeLabel on StatsTimeRange {
  String get label => switch (this) {
    StatsTimeRange.fourWeeks => '4W',
    StatsTimeRange.threeMonths => '3M',
    StatsTimeRange.sixMonths => '6M',
    StatsTimeRange.oneYear => '1Y',
    StatsTimeRange.all => 'All',
  };

  int? get weekCount => switch (this) {
    StatsTimeRange.fourWeeks => 4,
    StatsTimeRange.threeMonths => 13,
    StatsTimeRange.sixMonths => 26,
    StatsTimeRange.oneYear => 52,
    StatsTimeRange.all => null,
  };
}

const statsShortMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatWeekAxisLabel(DateTime start) =>
    '${start.day} ${statsShortMonths[start.month - 1]}';

String formatWeekDetailLabel(DateTime start) =>
    '${start.day} ${statsShortMonths[start.month - 1]} ${start.year}';

String formatExactStatNumber(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}

DateTime startOfWeek(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}
