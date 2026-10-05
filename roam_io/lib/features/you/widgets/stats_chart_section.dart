import 'package:flutter/material.dart';

import '../models/stats_metric_bucket.dart';
import 'stats_section_card.dart';
import 'stats_weekly_chart.dart';

/// Spacious weekly trend section on Stats pages.
class StatsChartSection extends StatelessWidget {
  const StatsChartSection({
    super.key,
    required this.title,
    required this.buckets,
    required this.emptyMessage,
    this.bucketsForRange,
    this.detailLabelBuilder,
    this.hasData = true,
    this.rangeStorageId,
  });

  final String title;
  final List<StatsMetricBucket> buckets;
  final String emptyMessage;
  final List<StatsMetricBucket> Function(StatsTimeRange range)? bucketsForRange;
  final String Function(StatsMetricBucket bucket)? detailLabelBuilder;
  final bool hasData;
  final String? rangeStorageId;

  @override
  Widget build(BuildContext context) {
    return StatsSectionCard(
      title: title,
      child: StatsWeeklyChart(
        buckets: buckets,
        bucketsForRange: bucketsForRange,
        emptyMessage: emptyMessage,
        detailLabelBuilder: detailLabelBuilder,
        hasData: hasData,
        rangeStorageId: rangeStorageId,
      ),
    );
  }
}
