import 'package:flutter/material.dart';

import '../providers/stats_analytics_provider.dart';
import '../services/stats_aggregation_service.dart';
import '../widgets/stats_breakdown_section.dart';
import '../widgets/stats_chart_section.dart';
import '../widgets/stats_hero_row.dart';
import '../widgets/stats_insight_card.dart';
import '../widgets/stats_recent_journeys_list.dart';

/// Journeys category on the Statistics page.
class JourneysStatsView extends StatelessWidget {
  const JourneysStatsView({
    super.key,
    required this.analytics,
    this.aggregationService = const StatsAggregationService(),
    this.embedded = false,
  });

  final StatsAnalyticsProvider analytics;
  final StatsAggregationService aggregationService;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final journeys = analytics.journeys;
    final totalDistanceKm =
        aggregationService.totalJourneyDistance(journeys) / 1000;
    final totalHours = aggregationService.totalJourneySeconds(journeys) / 3600;
    final buckets = aggregationService.journeyBuckets(journeys);
    final modeBreakdown = aggregationService.transportModeBreakdown(journeys);
    final insight = aggregationService.journeyInsightMessage(journeys);

    final body = Column(
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
        const SizedBox(height: 16),
        StatsBreakdownSection(
          title: 'Transport modes',
          items: modeBreakdown,
          emptyMessage: 'No journeys to break down yet',
        ),
        const SizedBox(height: 16),
        StatsJourneyHighlights(journeys: journeys),
        const SizedBox(height: 16),
        StatsInsightCard(message: insight, icon: Icons.route_rounded),
        const SizedBox(height: 16),
        StatsRecentJourneysList(journeys: journeys),
      ],
    );

    if (embedded) return body;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: body,
    );
  }
}
