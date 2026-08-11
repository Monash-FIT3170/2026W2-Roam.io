import 'package:flutter/material.dart';

import '../../profile/domain/xp_event.dart';
import '../providers/stats_analytics_provider.dart';
import '../services/stats_aggregation_service.dart';
import '../widgets/stats_chart_section.dart';
import '../widgets/stats_hero_row.dart';

/// XP category on the Stats tab.
class XpStatsView extends StatelessWidget {
  const XpStatsView({
    super.key,
    required this.analytics,
    this.aggregationService = const StatsAggregationService(),
  });

  final StatsAnalyticsProvider analytics;
  final StatsAggregationService aggregationService;

  @override
  Widget build(BuildContext context) {
    final xpThisWeek = aggregationService.xpThisWeek(analytics.xpEvents);
    final xpBySource = aggregationService.xpBySource(analytics.xpEvents);
    final buckets = analytics.xpEvents.isEmpty
        ? aggregationService.emptyRecentBuckets()
        : aggregationService.weeklyBucketsFromXpEvents(analytics.xpEvents);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(
          children: [
            StatsHeroStat(
              label: 'Total XP',
              value: formatCompactStatNumber(
                analytics.statsSummary.totalXpFromSources > 0
                    ? analytics.statsSummary.totalXpFromSources
                    : analytics.xpEvents.fold<int>(
                        0,
                        (sum, event) => sum + event.amount,
                      ),
              ),
            ),
            StatsHeroStat(
              label: 'XP this week',
              value: formatCompactStatNumber(xpThisWeek),
            ),
            StatsHeroStat(
              label: 'From visits',
              value: formatCompactStatNumber(
                xpBySource[XpEventSource.visit] ?? 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StatsChartSection(
          title: 'XP gained by week',
          buckets: buckets,
          emptyMessage: 'No XP gained yet this period',
          detailLabelBuilder: (bucket) => bucket.detailLabel(' XP'),
        ),
        ],
      ),
    );
  }
}
