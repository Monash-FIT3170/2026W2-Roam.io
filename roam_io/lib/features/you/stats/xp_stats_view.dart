import 'package:flutter/material.dart';

import '../../profile/domain/xp_event.dart';
import '../providers/stats_analytics_provider.dart';
import '../services/stats_aggregation_service.dart';
import '../widgets/stats_breakdown_section.dart';
import '../widgets/stats_chart_section.dart';
import '../widgets/stats_hero_row.dart';
import '../widgets/stats_insight_card.dart';
import '../widgets/stats_recent_xp_list.dart';

/// XP category on the Statistics page.
class XpStatsView extends StatelessWidget {
  const XpStatsView({
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
    final xpThisWeek = aggregationService.xpThisWeek(analytics.xpEvents);
    final xpBySource = aggregationService.xpBySource(analytics.xpEvents);
    final sourceBreakdown = aggregationService.xpSourceBreakdown(
      eventTotals: xpBySource,
      summary: analytics.statsSummary,
    );
    final buckets = analytics.xpEvents.isEmpty
        ? aggregationService.emptyRecentBuckets()
        : aggregationService.weeklyBucketsFromXpEvents(analytics.xpEvents);
    final insight = aggregationService.xpInsightMessage(
      events: analytics.xpEvents,
      streakDays: analytics.statsSummary.currentXpStreakDays,
      xpThisWeek: xpThisWeek,
      xpLastWeek: aggregationService.xpLastWeek(analytics.xpEvents),
    );

    final body = Column(
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
                xpBySource[XpEventSource.visit] ??
                    analytics.statsSummary.xpFromVisits,
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
        const SizedBox(height: 16),
        StatsBreakdownSection(
          title: 'XP by source',
          items: sourceBreakdown,
          emptyMessage: 'Earn XP from visits, tiles, and journeys',
          valueSuffix: ' XP',
        ),
        const SizedBox(height: 16),
        StatsInsightCard(message: insight),
        const SizedBox(height: 16),
        StatsRecentXpList(events: analytics.xpEvents),
      ],
    );

    if (embedded) return body;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: body,
    );
  }
}
