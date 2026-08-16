import 'package:flutter/material.dart';

import '../../map/data/visit.dart';
import '../providers/stats_analytics_provider.dart';
import '../services/stats_aggregation_service.dart';
import '../widgets/home_base_card.dart';
import '../widgets/recent_visited_locations_card.dart';
import '../widgets/stats_breakdown_section.dart';
import '../widgets/stats_chart_section.dart';
import '../widgets/stats_hero_row.dart';
import '../widgets/stats_section_card.dart';

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
    final categories = aggregationService.categoryBreakdown(
      events: analytics.visitEvents,
      visits: analytics.visits,
    );
    final furthestKm = aggregationService.furthestFromHomeKm(
      events: analytics.visitEvents,
      homeBase: analytics.homeBase,
    );
    final recentVisits = _recentVisitsForCard();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatsHeroStat(label: 'Unique places', value: '$uniquePlaces'),
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
          const SizedBox(height: 16),
          StatsBreakdownSection(
            title: 'Place categories',
            items: categories,
            emptyMessage: 'Visit places to see your category mix',
          ),
          const SizedBox(height: 16),
          HomeBaseCard(analytics: analytics),
          if (furthestKm != null) ...[
            const SizedBox(height: 16),
            StatsSectionCard(
              title: 'Furthest from home',
              child: Text(
                '${furthestKm.toStringAsFixed(1)} km from your home base',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Recent visits',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          RecentVisitedLocationsCard(
            visits: recentVisits,
            isLoading: !analytics.recentVisitsReady,
            error: analytics.recentVisitsError,
          ),
        ],
      ),
    );
  }

  List<Visit> _recentVisitsForCard() {
    if (analytics.recentVisits.isNotEmpty) {
      return analytics.recentVisits;
    }

    if (analytics.visitEvents.isEmpty) {
      return analytics.visits;
    }

    return analytics.visitEvents.map((event) {
      return Visit(
        placeId: event.placeId,
        googlePlaceId: event.googlePlaceId,
        placeName: event.placeName,
        regionId: event.regionId,
        category: event.category,
        visitedAt: event.visitedAt,
      );
    }).toList();
  }
}
