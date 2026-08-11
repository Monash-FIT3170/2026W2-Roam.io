import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';
import '../../profile/domain/profile_model.dart';
import '../providers/stats_analytics_provider.dart';
import '../services/stats_aggregation_service.dart';

/// Compact hero strip shown above Stats category tabs.
class StatsHeroStrip extends StatelessWidget {
  const StatsHeroStrip({
    super.key,
    required this.profile,
    required this.analytics,
    this.aggregationService = const StatsAggregationService(),
  });

  final ProfileModel? profile;
  final StatsAnalyticsProvider analytics;
  final StatsAggregationService aggregationService;

  @override
  Widget build(BuildContext context) {
    final xpThisWeek = aggregationService.xpThisWeek(analytics.xpEvents);
    final xpLastWeek = aggregationService.xpLastWeek(analytics.xpEvents);
    final delta = xpThisWeek - xpLastWeek;
    final deltaLabel = delta == 0
        ? 'Same as last week'
        : delta > 0
        ? '+$delta vs last week'
        : '$delta vs last week';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppSurfaces.border(context)),
      ),
      child: Row(
        children: [
          StatsHeroStat(label: 'Level', value: '${profile?.level ?? 1}'),
          StatsHeroStat(
            label: 'Total XP',
            value: formatCompactStatNumber(profile?.xp ?? 0),
          ),
          StatsHeroStat(
            label: 'XP this week',
            value: formatCompactStatNumber(xpThisWeek),
            delta: deltaLabel,
          ),
          StatsHeroStat(
            label: 'Streak',
            value: '${analytics.statsSummary.currentXpStreakDays}d',
          ),
        ],
      ),
    );
  }
}

/// Shared hero stat cell for Stats category pages.
class StatsHeroStat extends StatelessWidget {
  const StatsHeroStat({
    super.key,
    required this.label,
    required this.value,
    this.delta,
  });

  final String label;
  final String value;
  final String? delta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppSurfaces.textMuted(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppSurfaces.textPrimary(context),
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 2),
            Text(
              delta!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String formatCompactStatNumber(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}k';
  }
  return '$value';
}
