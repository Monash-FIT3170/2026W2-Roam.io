import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';
import '../models/stats_metric_bucket.dart';
import 'stats_weekly_chart.dart';

/// Card wrapper for weekly trend charts on Stats pages.
class StatsChartSection extends StatelessWidget {
  const StatsChartSection({
    super.key,
    required this.title,
    required this.buckets,
    required this.emptyMessage,
    this.detailLabelBuilder,
  });

  final String title;
  final List<StatsMetricBucket> buckets;
  final String emptyMessage;
  final String Function(StatsMetricBucket bucket)? detailLabelBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppSurfaces.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppSurfaces.textPrimary(context),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          StatsWeeklyChart(
            buckets: buckets,
            emptyMessage: emptyMessage,
            detailLabelBuilder: detailLabelBuilder,
          ),
        ],
      ),
    );
  }
}
