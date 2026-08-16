import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';
import '../../profile/domain/profile_model.dart';
import '../models/explorer_rank.dart';
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
    final theme = Theme.of(context);
    final level = profile?.level ?? 1;
    final xp = profile?.xp ?? 0;
    final rank = ExplorerRank.forLevel(level);
    final xpThisWeek = aggregationService.xpThisWeek(analytics.xpEvents);
    final streakDays = analytics.statsSummary.currentXpStreakDays;

    final totalXpForLevel = ProfileModel.totalXpToReachLevel(level);
    final currentLevelXp = xp - totalXpForLevel;
    final nextLevelXp = level >= ProfileModel.maxLevel
        ? currentLevelXp
        : ProfileModel.xpForLevel(level);
    final progress = level >= ProfileModel.maxLevel
        ? 1.0
        : (nextLevelXp > 0 ? currentLevelXp / nextLevelXp : 0.0);
    final xpBarLabel = level >= ProfileModel.maxLevel
        ? 'Max level'
        : '${formatCompactStatNumber(currentLevelXp)} / '
            '${formatCompactStatNumber(nextLevelXp)} XP';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppSurfaces.border(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _LevelBadge(level: level, assetPath: rank.assetPath),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rank.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppSurfaces.textPrimary(context),
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                _XpProgressBar(
                  progress: progress.clamp(0.0, 1.0),
                  label: xpBarLabel,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Gained this week: +$xpThisWeek XP',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppSurfaces.textPrimary(context),
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Streak: ${streakDays}d 🔥',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppSurfaces.textPrimary(context),
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({
    required this.level,
    required this.assetPath,
  });

  final int level;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            assetPath,
            width: 72,
            height: 72,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          Text(
            '$level',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              height: 1.0,
              fontSize: level >= 100 ? 18 : 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _XpProgressBar extends StatelessWidget {
  const _XpProgressBar({
    required this.progress,
    required this.label,
  });

  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = const Color(0xFF2F5D3A);
    final track = AppSurfaces.isDark(context)
        ? const Color(0xFF2A2F38)
        : const Color(0xFFD8D8D8);

    return SizedBox(
      height: 22,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: track),
            FractionallySizedBox(
              widthFactor: progress,
              alignment: Alignment.centerLeft,
              child: ColoredBox(color: fill),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppSurfaces.isDark(context)
                        ? Colors.white
                        : Colors.black,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
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
