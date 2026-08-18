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
    final weekLabel = formatWeekAxisLabel(weekStart);
    final suffix = unit.isEmpty ? '' : ' $unit';
    return 'Week of $weekLabel · $value$metricLabel$suffix';
  }
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

DateTime startOfWeek(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}
