import 'package:flutter/material.dart';

import '../providers/stats_analytics_provider.dart';
import '../services/stats_aggregation_service.dart';
import '../widgets/stats_chart_section.dart';
import '../widgets/stats_hero_row.dart';

/// Locations category on the Stats tab.
class LocationsStatsView extends StatelessWidget {
  const LocationsStatsView({
    super.key,
    required this.analytics,
    this.aggregationService = const StatsAggregationService(),
  });

  final StatsAnalyticsProvider analytics;
  final StatsAggregationService aggregationService;

  @override
  Widget build(BuildContext context) {
    final totalVisits = aggregationService.totalVisitEvents(analytics.visits);
    final uniquePlaces = aggregationService.uniquePlaces(analytics.visits);
    final revisitRate = totalVisits == 0
        ? 0
        : ((1 - uniquePlaces / totalVisits) * 100).round();
    final buckets = analytics.visitEvents.isNotEmpty
        ? aggregationService.visitEventBuckets(analytics.visitEvents)
        : aggregationService.visitSummaryBuckets(analytics.visits);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(
          children: [
            StatsHeroStat(
              label: 'Unique places',
              value: '$uniquePlaces',
            ),
            StatsHeroStat(label: 'Total visits', value: '$totalVisits'),
            StatsHeroStat(label: 'Revisit rate', value: '$revisitRate%'),
          ],
        ),
        const SizedBox(height: 16),
        StatsChartSection(
          title: 'Visits by week',
          buckets: buckets,
          emptyMessage: 'No locations to chart yet',
          detailLabelBuilder: (bucket) =>
              bucket.detailLabel(' Locations Visited'),
        ),
        ],
      ),
    );
  }
}
