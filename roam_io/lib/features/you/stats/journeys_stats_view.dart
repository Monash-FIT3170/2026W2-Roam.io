import 'package:flutter/material.dart';

import '../providers/stats_analytics_provider.dart';
import '../services/stats_aggregation_service.dart';
import '../widgets/stats_chart_section.dart';
import '../widgets/stats_hero_row.dart';

/// Journeys category on the Stats tab.
class JourneysStatsView extends StatelessWidget {
  const JourneysStatsView({
    super.key,
    required this.analytics,
    this.aggregationService = const StatsAggregationService(),
  });

  final StatsAnalyticsProvider analytics;
  final StatsAggregationService aggregationService;

  @override
  Widget build(BuildContext context) {
    final journeys = analytics.journeys;
    final totalDistanceKm =
        aggregationService.totalJourneyDistance(journeys) / 1000;
    final totalHours =
        aggregationService.totalJourneySeconds(journeys) / 3600;
    final buckets = aggregationService.journeyBuckets(journeys);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(
          children: [
            StatsHeroStat(label: 'Journeys', value: '${journeys.length}'),
            StatsHeroStat(
              label: 'Distance',
              value: '${totalDistanceKm.toStringAsFixed(1)} km',
            ),
            StatsHeroStat(
              label: 'Time',
              value: '${totalHours.toStringAsFixed(1)} hrs',
            ),
          ],
        ),
        const SizedBox(height: 16),
        StatsChartSection(
          title: 'Journeys by week',
          buckets: buckets,
          emptyMessage: 'No journeys to chart yet',
          detailLabelBuilder: (bucket) =>
              bucket.detailLabel(' Journeys Completed'),
        ),
        ],
      ),
    );
  }
}
