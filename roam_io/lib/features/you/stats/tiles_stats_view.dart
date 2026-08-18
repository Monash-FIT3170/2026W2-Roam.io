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
    this.embedded = false,
  });

  final StatsAnalyticsProvider analytics;
  final StatsAggregationService aggregationService;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final tileCount = aggregationService.tileCountFromSummary(
      analytics.statsSummary,
      analytics.tileRecords,
    );
    final revealed = aggregationService.revealedAreaSquareMetres(
      summary: analytics.statsSummary,
      polygonMeta: analytics.polygonMeta,
      tileCount: tileCount,
    );
    final coverage = aggregationService.formatCoveragePercent(
      revealed.squareMetres,
    );
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

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StatsHeroStat(label: 'Tiles unlocked', value: '$tileCount'),
            StatsHeroStat(
              label: 'Area revealed',
              value: aggregationService.formatAreaKm2(
                revealed.squareMetres,
                isEstimated: revealed.isEstimated,
              ),
            ),
            StatsHeroStat(label: 'City mapped', value: coverage),
          ],
        ),
        const SizedBox(height: 16),
        StatsChartSection(
          title: 'Tiles unlocked by week',
          buckets: buckets,
          emptyMessage: 'No unlocked tiles to chart yet',
          detailLabelBuilder: (bucket) => bucket.detailLabel(' Tiles Unlocked'),
        ),
        const SizedBox(height: 16),
        StatsSectionCard(
          title: 'Unlock streak',
          child: Text(
            unlockStreak == 0
                ? 'Unlock tiles on consecutive days to build a streak'
                : '$unlockStreak-day unlock streak',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 16),
        StatsInsightCard(message: insight, icon: Icons.grid_view_rounded),
        const SizedBox(height: 16),
        StatsLoyaltyTilesSection(tiles: loyaltyTiles),
      ],
    );

    if (embedded) return body;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: body,
    );
  }
}
