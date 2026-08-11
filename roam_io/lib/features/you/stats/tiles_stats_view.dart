import 'package:flutter/material.dart';

import '../providers/stats_analytics_provider.dart';
import '../services/stats_aggregation_service.dart';
import '../widgets/stats_chart_section.dart';
import '../widgets/stats_hero_row.dart';

/// Tiles category on the Stats tab.
class TilesStatsView extends StatelessWidget {
  const TilesStatsView({
    super.key,
    required this.analytics,
    this.aggregationService = const StatsAggregationService(),
  });

  final StatsAnalyticsProvider analytics;
  final StatsAggregationService aggregationService;

  @override
  Widget build(BuildContext context) {
    final tileCount = aggregationService.tileCountFromSummary(
      analytics.statsSummary,
      analytics.tileRecords,
    );
    final areaKm2 = analytics.statsSummary.totalAreaSquareMetres / 1e6;
    final buckets = aggregationService.tileUnlockBuckets(analytics.tileRecords);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(
          children: [
            StatsHeroStat(label: 'Tiles unlocked', value: '$tileCount'),
            StatsHeroStat(
              label: 'Area revealed',
              value: '${areaKm2.toStringAsFixed(2)} km²',
            ),
            const StatsHeroStat(label: 'City mapped', value: '—'),
          ],
        ),
        const SizedBox(height: 16),
        StatsChartSection(
          title: 'Tiles unlocked by week',
          buckets: buckets,
          emptyMessage: 'No unlocked tiles to chart yet',
          detailLabelBuilder: (bucket) =>
              bucket.detailLabel(' Tiles Unlocked'),
        ),
        ],
      ),
    );
  }
}
