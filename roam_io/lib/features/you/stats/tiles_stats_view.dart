import 'package:flutter/material.dart';

import '../providers/stats_analytics_provider.dart';
import '../services/stats_aggregation_service.dart';
import '../widgets/stats_chart_section.dart';
import '../widgets/stats_hero_row.dart';
import '../widgets/stats_insight_card.dart';
import '../widgets/stats_loyalty_tiles_section.dart';
import '../widgets/stats_section_card.dart';

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
    final areaM2 = analytics.statsSummary.totalAreaSquareMetres > 0
        ? analytics.statsSummary.totalAreaSquareMetres
        : analytics.polygonMeta.values.fold<double>(
            0,
            (sum, meta) => sum + (meta.areaSquareMetres ?? 0),
          );
    final areaKm2 = areaM2 / 1e6;
    final coverage = aggregationService.melbourneCoveragePercent(areaM2);
    final unlockStreak = aggregationService.unlockStreakDays(
      analytics.tileRecords,
    );
    final buckets = aggregationService.tileUnlockBuckets(analytics.tileRecords);
    final loyaltyTiles = aggregationService.topTilesByEntryCount(
      entryCounts: analytics.entryCounts,
      metaByPolygonId: analytics.polygonMeta,
    );
    final insight = aggregationService.tilesInsightMessage(
      metaByPolygonId: analytics.polygonMeta,
      entryCounts: analytics.entryCounts,
      unlockStreak: unlockStreak,
    );

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
              StatsHeroStat(
                label: 'City mapped',
                value: '${coverage.toStringAsFixed(2)}%',
              ),
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
          const SizedBox(height: 16),
          StatsSectionCard(
            title: 'Unlock streak',
            child: Text(
              unlockStreak == 0
                  ? 'Unlock tiles on consecutive days to build a streak'
                  : '$unlockStreak-day unlock streak',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          StatsInsightCard(
            message: insight,
            icon: Icons.grid_view_rounded,
          ),
          const SizedBox(height: 16),
          StatsLoyaltyTilesSection(tiles: loyaltyTiles),
        ],
      ),
    );
  }
}
